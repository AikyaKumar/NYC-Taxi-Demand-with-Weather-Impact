#!/usr/bin/env python3
"""
Cloud Function / Cloud Run job: **trigger_real_raw_bq_orchestrated**
====================================================================
Orchestrates the ingestion of daily live weather data, with added
deduplication logic to prevent duplicate rows in BigQuery.
"""

import os
import argparse
import logging
from datetime import datetime, timedelta

from google.cloud import storage  # type: ignore
from google.api_core.exceptions import NotFound

from pyspark.sql import SparkSession, functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType,
    IntegerType, TimestampType
)
from pyspark.sql import DataFrame as TDataFrame

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- CONFIG ---
BQ_PROJECT = os.getenv("BQ_PROJECT", "dm2-project-479611")
BQ_DATASET = os.getenv("BQ_DATASET", "dm2_aikya")
BQ_TABLE_WEATHER = "nyc_weather_raw"

ORIGINAL_BUCKET = "dm2-aikya"
PROCESSED_BUCKET = os.getenv("PROCESSED_BUCKET", "dm2-aikya-processed")
TEMP_BUCKET = os.getenv("TEMP_BUCKET", f"gs://{PROCESSED_BUCKET}-temp")

# -------------------------------------------------------------------------
#  UPDATED TARGET SCHEMA — MATCHES BIGQUERY SCHEMA (NO INGEST DATETIME)
# -------------------------------------------------------------------------
TARGET_SCHEMA = StructType([
    StructField("latitude", DoubleType(), True),
    StructField("longitude", DoubleType(), True),
    StructField("timezone", StringType(), True),
    StructField("weather_code", IntegerType(), True),
    StructField("hourly_timestamp", TimestampType(), True),
    StructField("temperature_2m", DoubleType(), True),
    StructField("relative_humidity_2m", IntegerType(), True),
    StructField("precipitation", DoubleType(), True),
    StructField("cloudcover", IntegerType(), True),
    StructField("windspeed_10m", DoubleType(), True),
    StructField("is_day", IntegerType(), True),
])

# -------------------------------------------------------------------------
# 1. INIT SPARK
# -------------------------------------------------------------------------
def init_spark(app_name: str, temp_bucket: str) -> SparkSession:
    logger.info("Initializing Spark session")
    temp_bucket_clean = temp_bucket.replace("gs://", "")

    spark = (
        SparkSession.builder
        .appName(app_name)
        .config(
            "spark.jars.packages",
            "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.36.0",
        )
        .config("temporaryGcsBucket", temp_bucket_clean)
        .getOrCreate()
    )

    return spark

# -------------------------------------------------------------------------
# 2. PROCESS WEATHER DATA
# -------------------------------------------------------------------------
def process_weather_data(spark: SparkSession, file_path_glob: str) -> TDataFrame:
    try:
        logger.info(f"Reading raw JSON from: {file_path_glob}")

        # Read JSON with multiLine option for proper parsing
        df_raw = spark.read.option("multiLine", True).json(file_path_glob)

        if df_raw.rdd.isEmpty():
            logger.warning(f"No data found in JSON: {file_path_glob}")
            return spark.createDataFrame([], schema=TARGET_SCHEMA)

        # Log the schema for debugging
        logger.info("Raw JSON schema:")
        df_raw.printSchema()

        # Explode and flatten the "rows" array structure
        if "rows" not in df_raw.columns:
            logger.warning(f"No 'rows' column found in JSON. Assuming flat structure.")
            df_flattened = df_raw
        else:
            logger.info("Exploding 'rows' array and flattening structure")
            df_exploded = df_raw.select(F.explode("rows").alias("row"))
            df_flattened = df_exploded.select("row.*")

        logger.info("Flattened schema:")
        df_flattened.printSchema()

        # Map column names to match target schema
        column_mapping = {
            "latitude": "latitude",
            "longitude": "longitude", 
            "timezone": "timezone",
            "weather_code": "weather_code",
            "hourly_timestamp": "hourly_timestamp",
            "temperature_2m": "temperature_2m",
            "relative_humidity_2m": "relative_humidity_2m",
            "precipitation": "precipitation",
            "cloudcover": "cloudcover",
            "windspeed_10m": "windspeed_10m",
            "is_day": "is_day"
        }

        # Select and rename columns
        selected_cols = []
        for target_col in column_mapping:
            json_col = column_mapping[target_col]
            if json_col in df_flattened.columns:
                selected_cols.append(F.col(json_col).alias(target_col))
            else:
                logger.warning(f"Column '{json_col}' not found in data.")
                selected_cols.append(F.lit(None).alias(target_col))

        df_mapped = df_flattened.select(*selected_cols)

        # Convert hourly_timestamp string to timestamp if needed
        if "hourly_timestamp" in df_mapped.columns:
            field_type = dict(df_mapped.dtypes)["hourly_timestamp"]
            if field_type == "string":
                logger.info("Converting hourly_timestamp from string to timestamp")
                df_mapped = df_mapped.withColumn(
                    "hourly_timestamp", 
                    F.to_timestamp("hourly_timestamp")
                )

        # Apply target schema ordering and cast types
        df_final = df_mapped.select(*[field.name for field in TARGET_SCHEMA.fields])
        for field in TARGET_SCHEMA.fields:
            if field.name in df_final.columns:
                df_final = df_final.withColumn(field.name, F.col(field.name).cast(field.dataType))

        row_count = df_final.count()
        logger.info(f"Processed rows before deduplication: {row_count}")

        if row_count > 0:
            logger.info("Sample data:")
            df_final.show(5, truncate=False)

        return df_final

    except Exception as e:
        logger.error(f"Error during Spark processing: {e}")
        logger.exception("Full traceback:")
        return spark.createDataFrame([], schema=TARGET_SCHEMA)

# -------------------------------------------------------------------------
# 3. WRITE TO BIGQUERY (MODIFIED FOR DEDUPLICATION)
# -------------------------------------------------------------------------
def write_to_bq(spark: SparkSession, df: TDataFrame, table_fqdn: str):
    from google.cloud import bigquery
    
    row_count = df.count()
    if row_count == 0:
        logger.warning("No rows to write to BigQuery.")
        return
    
    # 1. Determine the BigQuery table reference
    table_ref = f"{BQ_PROJECT}:{BQ_DATASET}.{BQ_TABLE_WEATHER}"
    
    # 2. Check if the table exists (using Google Cloud BigQuery client)
    bq_client = bigquery.Client(project=BQ_PROJECT)
    table_exists = True
    try:
        bq_client.get_table(table_ref.replace(':', '.'))
    except NotFound:
        table_exists = False

    if not table_exists:
        # If table doesn't exist, write all data and create the table
        logger.info(f"Table {table_fqdn} doesn't exist. Creating and writing all {row_count} rows.")
        df.write \
            .format("bigquery") \
            .option("table", table_fqdn) \
            .option("timePartitioningField", "hourly_timestamp") \
            .option("timePartitioningType", "DAY") \
            .mode("overwrite") \
            .save()
        logger.info("Initial write complete.")
        return

    # 3. Table exists: Load existing keys for deduplication
    logger.info(f"Table {table_fqdn} exists. Checking for duplicates...")
    
    # Define the unique key columns
    unique_keys = ["latitude", "longitude", "hourly_timestamp"]
    
    # Read only the unique keys from the existing BQ table
    try:
        df_existing = spark.read \
            .format("bigquery") \
            .option("table", table_fqdn) \
            .load() \
            .select(*unique_keys)
        
        logger.info(f"Successfully loaded existing data keys.")
    except Exception as e:
        logger.error(f"Failed to read existing BQ data for deduplication: {e}")
        # If reading fails, better to write nothing than risk massive duplicates.
        return

    # 4. Perform Anti-Join (Deduplication)
    # Keep rows in 'df' that DO NOT have a matching key in 'df_existing'
    df_deduped = df.alias("new").join(
        df_existing.alias("existing"),
        on=unique_keys,
        how="left_anti"
    )

    deduped_count = df_deduped.count()
    dropped_count = row_count - deduped_count
    
    if deduped_count == 0:
        logger.warning(f"0 new rows found after deduplication. {dropped_count} duplicates skipped.")
        return
        
    logger.info(f"Writing {deduped_count} new rows (skipped {dropped_count} duplicates) to BigQuery via WRITE_APPEND.")
    
    # 5. Write only the new, deduplicated data using append mode
    df_deduped.write \
        .format("bigquery") \
        .option("table", table_fqdn) \
        .option("timePartitioningField", "hourly_timestamp") \
        .option("timePartitioningType", "DAY") \
        .mode("append") \
        .save()
    
    logger.info("Append write complete.")

# -------------------------------------------------------------------------
# 4. MAIN (REVISED FOR TARGETED SOURCE FOLDER CLEANUP)
# -------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gcs_prefix", required=True, 
                       help="GCS prefix where JSON files are stored (e.g., 'raw/weather/'). This is the folder to clean up.")
    parser.add_argument("--target_date", required=False, 
                       help="Target date (optional, for backward compatibility)")
    parser.add_argument("--timezone", default="UTC",
                       help="Timezone for date calculations")

    args = parser.parse_args()
    
    logger.info(f"Starting weather data ingestion with prefix: {args.gcs_prefix}")
    
    gcs_client = storage.Client()
    spark = init_spark("DataprocWeatherIngestion", TEMP_BUCKET)
    table_fqdn = f"{BQ_PROJECT}.{BQ_DATASET}.{BQ_TABLE_WEATHER}"
    
    processed_original_blob_names = [] 
    
    try:
        original_bucket = gcs_client.bucket(ORIGINAL_BUCKET)
        dest_bucket = gcs_client.bucket(PROCESSED_BUCKET)
        
        # Determine the source prefix path to clean up later
        source_prefix_to_clean = args.gcs_prefix.rstrip('/') + '/' if args.gcs_prefix else ''
        logger.info(f"Targeting files under prefix: {source_prefix_to_clean}")
        
        # List all blobs under the given prefix
        blobs = list(original_bucket.list_blobs(prefix=source_prefix_to_clean))
        
        if not blobs:
            logger.warning(f"No source files found under prefix: {source_prefix_to_clean}")
        else:
            logger.info(f"Found {len(blobs)} item(s) to process/check")
            
            for original_blob in blobs:
                original_name = original_blob.name
                
                # Skip directories/empty files (including the directory marker itself if it exists)
                if original_name == source_prefix_to_clean or original_name.endswith('/') or original_blob.size == 0:
                    logger.info(f"Skipping directory marker/empty item: {original_name}")
                    continue
                    
                logger.info(f"Processing file: {original_name}")
                
                # --- 1. Copy to processed bucket (Archive) ---
                dest_bucket.copy_blob(original_blob, dest_bucket, original_name)
                logger.info(f"Copied to processed bucket (Archive): {original_name}")
                
                # --- 2. Process the file from the processed bucket ---
                spark_input_path = f"gs://{PROCESSED_BUCKET}/{original_name}"
                df_clean = process_weather_data(spark, spark_input_path)
                
                # --- 3. Write to BigQuery and track success ---
                if df_clean.count() > 0:
                    write_to_bq(spark, df_clean, table_fqdn) 
                    processed_original_blob_names.append(original_name)
                    logger.info(f"Successfully processed and archived: {original_name}")
                else:
                    logger.warning(f"Empty DF after processing {original_name}. Skipping original file deletion.")
        
        # --- 4. Delete processed source files from original bucket (Staging) ---
        if processed_original_blob_names:
            logger.info(f"Deleting {len(processed_original_blob_names)} processed source files from original bucket...")
            for blob_name in processed_original_blob_names:
                try:
                    # Deleting from ORIGINAL_BUCKET
                    original_bucket.blob(blob_name).delete()
                    logger.info(f"Deleted file: {blob_name}")
                except NotFound:
                    logger.warning(f"Original file not found: {blob_name}")
                    pass
        
            # --- 5. Targeted Cleanup of the Source Prefix/Folder Marker ---
            
            # Check if any objects (excluding the folder marker itself) still exist under this prefix.
            # We use `delimiter='/'` to list only immediate children (files or subfolders).
            remaining_objects = list(original_bucket.list_blobs(
                prefix=source_prefix_to_clean,
                delimiter='/',
                max_results=1, 
                versions=False
            ))

            # If the list is empty, the folder is empty (only the marker might remain).
            if not remaining_objects:
                directory_marker_name = source_prefix_to_clean
                logger.info(f"Source prefix '{directory_marker_name}' appears empty after file deletion. Attempting to delete marker.")
                
                # Try to delete the directory marker blob itself
                try:
                    original_bucket.blob(directory_marker_name).delete()
                    logger.info(f"Successfully deleted empty source folder marker: {directory_marker_name}")
                except NotFound:
                    # This is expected if a marker blob never existed (GCS doesn't require them)
                    logger.info(f"No explicit folder marker found for deletion: {directory_marker_name}")
                except Exception as e:
                    logger.warning(f"Could not delete folder marker {directory_marker_name}: {e}")
            else:
                logger.info(f"Source prefix '{source_prefix_to_clean}' still contains other files or subfolders (not deleting folder marker).")

        
        logger.info("Processing and source cleanup completed successfully")
        
    except Exception as e:
        logger.exception(f"Job failed with error: {e}")
        raise
    finally:
        spark.stop()
        logger.info("Spark session stopped")

if __name__ == "__main__":
    main()