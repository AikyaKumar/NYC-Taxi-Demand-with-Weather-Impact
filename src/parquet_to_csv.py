import pandas as pd
import os

# --- Configuration ---
# The name of your input Parquet file (from your upload)
input_file = "yellow_tripdata_2025-02.parquet" 
# The desired name for the output CSV file
output_file = "data/static/yellow_tripdata_2025-02.csv" 
# Set index=False to prevent pandas from writing the DataFrame index as a column in the CSV
# Set encoding='utf-8' for standard compatibility
# ---------------------

try:
    # 1. Read the Parquet file into a pandas DataFrame
    print(f"Reading file: {input_file}...")
    df = pd.read_parquet(input_file)
    print(f"File loaded successfully. Data has {len(df):,} rows and {len(df.columns)} columns.")

    # 2. Write the DataFrame to a CSV file
    print(f"Writing data to CSV file: {output_file}...")
    df.to_csv(output_file, index=False, encoding='utf-8')
    
    # 3. Confirmation message
    print("Conversion complete!")
    print(f"The data has been saved to '{output_file}' in the same directory.")

    # 4. Display the first 10 rows of the DataFrame
    print("\n--- First 10 Rows of the Converted Data ---")
    # The .head(10) method shows the first 10 rows (including the header)
    print(df.head(10))
    print("------------------------------------------")

except FileNotFoundError:
    print(f"Error: The file '{input_file}' was not found. Make sure the file is in the same folder as this Python script.")
except Exception as e:
    print(f"An unexpected error occurred during conversion: {e}")