import requests
import pandas as pd
import os
from datetime import datetime, timezone
import pytz

# --- CONFIGURATION ---
LATITUDE = 40.710335
LONGITUDE = -73.99309

DATE_RANGES = [
    {
        "name": "jan_to_dec_2025",
        "start_date": "2025-10-01",
        "end_date": "2025-12-11",
        "csv_file": "data/static/nyc_weather_hist.csv"
    }
]

# 🎯 FINAL VARIABLE LIST: Includes only core metrics plus the critical 'is_day' and 'weather_code'.
# 'rain', 'snowfall', and 'precipitation_hours' have been removed to resolve the API error.
CORE_WEATHER_VARIABLES = [
    "temperature_2m", 
    "relative_humidity_2m", 
    "precipitation", 
    "cloudcover", 
    "wind_speed_10m",
    "weather_code",
    "is_day",
]

# API Endpoint (Retained the Forecast API for 'is_day' and 'weather_code' compatibility)
OPENMETEO_API_URL = "https://archive-api.open-meteo.com/v1/archive" 
TARGET_TIMEZONE = "America/New_York"
# ---------------------

def fetch_weather_data(date_range):
    """Fetches hourly weather data for a specific date range, transforms it, and saves it to CSV."""
    
    print(f"\n--- Fetching data for {date_range['name']} ---")
    print(f"Date range: {date_range['start_date']} to {date_range['end_date']}")
    print(f"Location: Lat={LATITUDE}, Lon={LONGITUDE}")
    print(f"Timezone: {TARGET_TIMEZONE}") 
    print(f"API Endpoint: {OPENMETEO_API_URL}")

    params = {
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
        "start_date": date_range['start_date'],
        "end_date": date_range['end_date'],
        "hourly": ",".join(CORE_WEATHER_VARIABLES),
        "timezone": TARGET_TIMEZONE,
        "temperature_unit": "celsius",
        "wind_speed_unit": "kmh",
        "precipitation_unit": "mm"
    }

    try:
        response = requests.get(OPENMETEO_API_URL, params=params, timeout=60)
        response.raise_for_status()
        data = response.json()
        
        if 'hourly' not in data or not data['hourly'].get('time'):
            print(f"Error: Hourly data section not found in API response for {date_range['name']}.")
            if 'reason' in data:
                 print(f"API Error Reason: {data.get('reason')}")
            return False

        df = pd.DataFrame(data['hourly'])
        
        # --- Schema Alignment and Column Addition ---
        
        # Add static location/time context columns
        df['latitude'] = LATITUDE
        df['longitude'] = LONGITUDE
        df['timezone'] = TARGET_TIMEZONE
        
        # Rename columns for schema compatibility
        column_map = {
            'time': 'hourly_timestamp',
            'wind_speed_10m': 'windspeed_10m'
        }
        df.rename(columns=column_map, inplace=True)

        # 5. Select and reorder columns to match the final desired schema
        target_columns = [
            "latitude", 
            "longitude", 
            "timezone", 
            "weather_code",
            "hourly_timestamp",
            "temperature_2m", 
            "relative_humidity_2m", 
            "precipitation", 
            "cloudcover", 
            "windspeed_10m",
            "is_day",
        ]
        
        # Filter the DataFrame to only contain target columns in the correct order
        df_final = df[target_columns]
        
        print(f"Successfully retrieved and structured {len(df_final):,} hourly records.")
        
        # Save the DataFrame to CSV file
        os.makedirs(os.path.dirname(date_range['csv_file']), exist_ok=True)
        df_final.to_csv(date_range['csv_file'], index=False, encoding='utf-8')
        
        print(f"✅ Data saved to: '{date_range['csv_file']}'")
        print(f"Sample data (Cleaned Schema Compliant):\n{df_final.head().to_string()}")
        
        return True

    except requests.exceptions.RequestException as e:
        print(f"CRITICAL ERROR: Failed to reach API or received error status for {date_range['name']}.")
        print(f"Details: {e}")
        return False
    except Exception as e:
        print(f"An unexpected error occurred for {date_range['name']}: {e}")
        return False

def fetch_historical_data_for_all_months():
    """Fetches historical data for all defined date ranges."""
    
    print("--- Starting Historical Weather Data Fetch ---")
    
    success_count = 0
    total_months = len(DATE_RANGES)
    
    for date_range in DATE_RANGES:
        success = fetch_weather_data(date_range) # Renamed function call
        if success:
            success_count += 1
    
    print(f"\n{'='*50}")
    print(f"SUMMARY: Successfully fetched data for {success_count} out of {total_months} date ranges")
    
    if success_count == total_months:
        print("✅ All data fetched successfully!")
    elif success_count > 0:
        print(f"⚠️  Partially successful: {success_count}/{total_months} ranges fetched")
    else:
        print("❌ No data was fetched successfully")

if __name__ == "__main__":
    os.makedirs('data/static', exist_ok=True)
    fetch_historical_data_for_all_months()