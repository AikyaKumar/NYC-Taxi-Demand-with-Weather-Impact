import pandas as pd
import numpy as np
import os

# --- Configuration ---
input_csv_file = "data/static/yellow_tripdata_2025-09.csv"
num_splits = 5 # Changed to 5, the number of files you want to create
base_filename = "data/static/yellow_tripdata_2025-09"
# ---------------------

try:
    # 1. Read the CSV file into a pandas DataFrame
    print(f"Reading file: {input_csv_file}...")
    df = pd.read_csv(input_csv_file)
    total_rows = len(df)
    print(f"File loaded successfully. Total rows: {total_rows:,}")

    # 2. Split the DataFrame into the specified number of parts (5)
    # np.array_split handles the division automatically, even if the total rows is not divisible by 5.
    df_parts = np.array_split(df, num_splits)
    
    print(f"\nAttempting to split the data into {num_splits} files...")

    # 3. Iterate through the list of split DataFrames and save each one
    for i, part in enumerate(df_parts, 1):
        # Create a unique filename for each part (e.g., 'yellow_tripdata_2025-10_Part1.csv')
        output_file_name = f"{base_filename}_Part{i}.csv"
        
        # Write the part to a new CSV file
        # index=False prevents writing the DataFrame index as a column
        part.to_csv(output_file_name, index=False, encoding='utf-8')
        
        print(f"File {i}/{num_splits} saved as '{output_file_name}' with {len(part):,} rows.")

    print("\n✅ Splitting complete!")
    print(f"The original file has been successfully divided into {num_splits} parts.")

except FileNotFoundError:
    print(f"Error: The file '{input_csv_file}' was not found. Please ensure the file name is correct.")
except Exception as e:
    print(f"An unexpected error occurred: {e}")