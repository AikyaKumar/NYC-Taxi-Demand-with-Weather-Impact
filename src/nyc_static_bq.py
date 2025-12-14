#!/usr/bin/env python3
"""
Cloud Run Job / DataProc Job: **nyc_static_ingestion_orchestrated**
===================================================================
Orchestrates the ingestion of static/incoming NYC taxi, zones, and weather data.

PIPELINE:
1. Spark ETL: Reads files directly from the ORIGINAL GCS bucket (dm2-aikya).
2. Spark Write: Transformed data is written to BigQuery (Append/Overwrite based on table type).
3. Spark Write: Transformed data is ALSO written to the PROCESSED GCS bucket (Append/Overwrite).
4. GCS Cleanup: Files are NOT deleted from the original bucket.

Dependencies:
- pyspark
- google-cloud-storage
- spark-bigquery-connector
"""

import os
import logging

from pyspark.sql import SparkSession, functions as F, types as T

# ------------------------------------------------------------------------------
# 0. CONFIG
# ------------------------------------------------------------------------------

# Set up logging to avoid repeating df.count() calls unnecessarily
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# --- GCS CONFIGURATION ---
ORIGINAL_BUCKET    = "dm2-aikya"
PROCESSED_BUCKET   = os.getenv("PROCESSED_BUCKET", "dm2-aikya-processed")
TEMP_BUCKET        = os.getenv("TEMP_BUCKET", f"gs://{PROCESSED_BUCKET}-temp")

# Source paths (Prefixes used for GCS operations)
# YELLOW_SOURCE_PREFIX = "static/nyc/yellow_trips/"
# ZONES_SOURCE_PREFIX  = "static/nyc/taxi_zones/"
WEATHER_SOURCE_PREFIX = "static/nyc/weather/"

# SPARK INPUT PATHS (Read from ORIGINAL BUCKET)
# YELLOW_INPUT_PATH  = f"gs://{ORIGINAL_BUCKET}/{YELLOW_SOURCE_PREFIX}*.csv"
# ZONES_INPUT_PATH   = f"gs://{ORIGINAL_BUCKET}/{ZONES_SOURCE_PREFIX}*.csv"
WEATHER_INPUT_PATH = f"gs://{ORIGINAL_BUCKET}/{WEATHER_SOURCE_PREFIX}*.csv"

# SPARK OUTPUT PATHS FOR PROCESSED BUCKET (Write parquet files here)
# YELLOW_OUTPUT_PATH  = f"gs://{PROCESSED_BUCKET}/{YELLOW_SOURCE_PREFIX}"
# ZONES_OUTPUT_PATH   = f"gs://{PROCESSED_BUCKET}/{ZONES_SOURCE_PREFIX}"
WEATHER_OUTPUT_PATH = f"gs://{PROCESSED_BUCKET}/{WEATHER_SOURCE_PREFIX}"


# --- BIGQUERY CONFIGURATION ---
BQ_PROJECT  = os.getenv("BQ_PROJECT", "dm2-project-479611")
BQ_DATASET  = os.getenv("BQ_DATASET", "dm2_aikya") 
# BQ_TABLE_YELLOW  = f"{BQ_PROJECT}.{BQ_DATASET}.nyc_yellow_taxi_raw"
# BQ_TABLE_ZONES   = f"{BQ_PROJECT}.{BQ_DATASET}.nyc_taxi_zones_raw"
BQ_TABLE_WEATHER = f"{BQ_PROJECT}.{BQ_DATASET}.nyc_weather_raw"


# ------------------------------------------------------------------------------
# 1. SPARK INIT
# ------------------------------------------------------------------------------

def init_spark(app_name: str, temp_bucket: str) -> SparkSession:
    """Initializes and configures the SparkSession for BigQuery access."""
    logging.info("Initializing Spark session")
    spark = (
        SparkSession.builder
        .appName(app_name)
        .config(
            "spark.jars.packages",
            "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.36.0",
        )
        .config("spark.sql.catalog.spark_bigquery", "com.google.cloud.spark.bigquery")
        .config("temporaryGcsBucket", temp_bucket)
        .getOrCreate()
    )
    return spark

# ------------------------------------------------------------------------------
# 2. LOADERS (Read from original GCS location)
# ------------------------------------------------------------------------------

def read_csv(spark: SparkSession, path: str):
    """Reads CSV data from the given GCS path."""
    logging.info(f"Reading CSV from {path}")
    df = (
        spark.read
        .option("header", "true")
        .option("inferSchema", "true")
        .csv(path)
    )
    logging.info("Read successful; schema: %s", df.schema.simpleString())
    return df

# ------------------------------------------------------------------------------
# 3. CLEANING / TRANSFORMATIONS
# ------------------------------------------------------------------------------

# def clean_yellow_trips(df):
#     """
#     Basic cleaning for yellow taxi trips:
#     - RENAME tpep columns to standardized names (Fix for AnalysisException)
#     - drop rows missing pickup/dropoff timestamps
#     - parse timestamps
#     - filter to October 2025
#     """
#     logging.info("Cleaning yellow taxi trips")
    
#     # --- FIX: RENAME COLUMNS to standardized names ---
#     if "tpep_pickup_datetime" in df.columns:
#         df = df.withColumnRenamed("tpep_pickup_datetime", "pickup_datetime")
#     if "tpep_dropoff_datetime" in df.columns:
#         df = df.withColumnRenamed("tpep_dropoff_datetime", "dropoff_datetime")
    
#     # Drop critical nulls (uses the renamed columns)
#     df = df.dropna(subset=["pickup_datetime", "dropoff_datetime"])

#     # Parse timestamps
#     df = (
#         df
#         .withColumn(
#             "pickup_datetime",
#             F.to_timestamp("pickup_datetime", "yyyy-MM-dd HH:mm:ss"),
#         )
#         .withColumn(
#             "dropoff_datetime",
#             F.to_timestamp("dropoff_datetime", "yyyy-MM-dd HH:mm:ss"),
#         )
#     )

#     # Filter to October 2025
#     df = df.filter(
#         (F.col("pickup_datetime") >= F.lit("2025-10-01"))
#         & (F.col("pickup_datetime") < F.lit("2025-11-01"))
#     )

#     # Cast key numeric columns defensively
#     numeric_cols = [
#         "passenger_count", "trip_distance", "fare_amount", "tip_amount",
#         "total_amount", "PULocationID", "DOLocationID"
#     ]
#     for c in numeric_cols:
#         if c in df.columns:
#             # Cast common floating point columns to DoubleType
#             if c in ["trip_distance", "fare_amount", "tip_amount", "total_amount"]:
#                  df = df.withColumn(c, F.col(c).cast(T.DoubleType()))
#             # Cast ID columns to IntegerType
#             elif c in ["PULocationID", "DOLocationID", "passenger_count"]:
#                  df = df.withColumn(c, F.col(c).cast(T.IntegerType()))
    
#     df = df.withColumn("ingest_datetime", F.current_timestamp())

#     logging.info("Yellow trips cleaning complete.")
#     return df


# def clean_taxi_zones(df):
#     """Basic cleaning for taxi zone lookup."""
#     logging.info("Cleaning taxi zones lookup")

#     if "LocationID" in df.columns:
#         df = df.withColumn("LocationID", F.col("LocationID").cast(T.IntegerType()))

#     df = df.withColumn("ingest_datetime", F.current_timestamp())
#     logging.info("Taxi zones cleaning complete.")
#     return df


def clean_weather(df):
    """Basic cleaning for hourly weather."""
    logging.info("Cleaning weather data")

    # --- START FIX ---
    # Check for 'hourly_timestamp' (as seen in the log) or 'time'
    if "hourly_timestamp" in df.columns and "timestamp" not in df.columns:
        df = df.withColumnRenamed("hourly_timestamp", "timestamp")
    # Keep the original 'time' check for backward compatibility/other sources
    elif "time" in df.columns and "timestamp" not in df.columns:
        df = df.withColumnRenamed("time", "timestamp")
    # --- END FIX ---

    # This line now works because the column is correctly named 'timestamp'
    df = df.dropna(subset=["timestamp"])
    
    df = df.withColumn("timestamp", F.to_timestamp("timestamp"))

    # ... rest of the function remains the same ...
    numeric_cols = [
        "temperature_2m", "rain", "snowfall", "precipitation",
        "wind_speed_10m", "relative_humidity_2m", "weather_code", "is_day"
    ]
    for c in numeric_cols:
        if c in df.columns:
            # Cast common weather metrics to DoubleType
            if c not in ["weather_code", "is_day"]:
                df = df.withColumn(c, F.col(c).cast(T.DoubleType()))
            # Cast weather codes/flags to IntegerType
            else:
                df = df.withColumn(c, F.col(c).cast(T.IntegerType()))

    df = df.withColumn("ingest_datetime", F.current_timestamp())
    logging.info("Weather cleaning complete.")
    return df

# ------------------------------------------------------------------------------
# 4. WRITE FUNCTIONS
# ------------------------------------------------------------------------------

def write_to_bq(df, table_fqdn: str, mode: str = "overwrite"):
    """Writes DataFrame to BigQuery table."""
    row_count = df.count()
    logging.info("Writing %s rows to BigQuery table: %s in mode %s", row_count, table_fqdn, mode)
    (
        df.write
        .format("bigquery")
        .option("table", table_fqdn)
        .mode(mode)
        .save()
    )
    logging.info("BigQuery write of %s rows completed.", row_count)

def write_to_gcs(df, path: str, mode: str = "overwrite", format: str = "parquet"):
    """Writes DataFrame to GCS location."""
    row_count = df.count()
    logging.info("Writing %s rows to GCS path: %s in mode %s", row_count, path, mode)
    (
        df.write
        .mode(mode)
        .format(format)
        .save(path)
    )
    logging.info("GCS write of %s rows completed.", row_count)

# ------------------------------------------------------------------------------
# 5. MAIN ORCHESTRATION
# ------------------------------------------------------------------------------

def main():
    
    logging.info("Starting NYC static ingestion (Read from SOURCE, Write to BQ and PROCESSED GCS)")
    
    # 1. Spark Init
    logging.info("\n--- 1. Spark Init and ETL (Read from ORIGINAL Bucket) ---")
    spark = init_spark("NYCStaticIngestion", TEMP_BUCKET)

    try:
        # --- Yellow trips (Append to BQ and GCS) ---
        # logging.info("\n--- Processing Yellow Taxi Data ---")
        # df_yellow_raw = read_csv(spark, YELLOW_INPUT_PATH)
        # df_yellow_clean = clean_yellow_trips(df_yellow_raw).cache() # Cache for multiple writes
        
        # # Write 1: BigQuery (Append mode for incremental data)
        # write_to_bq(df_yellow_clean, BQ_TABLE_YELLOW, mode="append") 
        
        # # Write 2: Processed GCS bucket (Append mode to accumulate processed data)
        # write_to_gcs(df_yellow_clean, YELLOW_OUTPUT_PATH, mode="append", format="parquet")

        # df_yellow_clean.unpersist()

        # # --- Taxi zones (Overwrite BQ and GCS lookup table) ---
        # logging.info("\n--- Processing Taxi Zones Data ---")
        # df_zones_raw = read_csv(spark, ZONES_INPUT_PATH)
        # df_zones_clean = clean_taxi_zones(df_zones_raw).cache()
        
        # # Write 1: BigQuery (Overwrite mode for lookup table)
        # write_to_bq(df_zones_clean, BQ_TABLE_ZONES, mode="overwrite")
        # # Write 2: Processed GCS bucket (Overwrite mode)
        # write_to_gcs(df_zones_clean, ZONES_OUTPUT_PATH, mode="overwrite", format="parquet")

        # df_zones_clean.unpersist()

        # --- Weather (Overwrite BQ and GCS historical dump) ---
        logging.info("\n--- Processing Weather Data ---")
        df_weather_raw = read_csv(spark, WEATHER_INPUT_PATH)
        df_weather_clean = clean_weather(df_weather_raw).cache()
        
        # Write 1: BigQuery (Overwrite mode for full historical dump)
        write_to_bq(df_weather_clean, BQ_TABLE_WEATHER, mode="overwrite")
        # Write 2: Processed GCS bucket (Overwrite mode)
        write_to_gcs(df_weather_clean, WEATHER_OUTPUT_PATH, mode="overwrite", format="parquet")

        df_weather_clean.unpersist()

        logging.info("NYC static ingestion job finished successfully ✅")

    except Exception:
        logging.exception("NYC static ingestion job FAILED ❌")
        # Ensure the job fails so Dataproc marks it as FAILED
        raise 
    finally:
        # Ensure Spark Context is always stopped
        spark.stop()


if __name__ == "__main__":
    main()