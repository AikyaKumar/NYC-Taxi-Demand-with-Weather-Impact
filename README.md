# 🚖 NYC Taxi Demand & Weather Impact Analysis

An end-to-end cloud ELT pipeline processing **1M+ NYC taxi trips** alongside daily weather observations to analyze how weather conditions drive demand surges, route shifts, and peak pickup windows[cite: 5].

---

### 📺 Project Walkthrough & Demo
👉 **[Watch the Interactive Video Demo & Presentation on Canva](https://canva.link/58rxepn1tz5fzj0)**

---

### 🏗 Architecture
- **Storage & Warehouse:** Google Cloud Storage (GCS) & BigQuery[cite: 5, 7]
- **Data Modeling:** dbt Core (Staging, Dimensions, Facts & Analytics Marts)[cite: 5, 7]
- **BI & Dashboards:** Tableau[cite: 5, 7]

Raw Taxi Data (1M+) + Weather Logs ──> GCS ──> BigQuery ──> dbt Core ──> Tableau

1. **Ingestion & Storage:** Ingested 1M+ records from the NYC Taxi & Limousine Commission (TLC) dataset joined with Open-Meteo historical weather observations[cite: 5].
2. **Transformations with dbt:**
   * **Staging (`stg_`):** Cleaned null coordinates, filtered invalid trip distances, and standardized timestamp intervals.
   * **Dimensions & Facts:** Star-schema modeling separating `dim_weather`, `dim_locations`, and `fct_taxi_trips`[cite: 5].
   * **Analytics Marts (`mart_`):** Pre-aggregated hourly weather-impact demand metrics feeding reporting layers directly[cite: 5].
3. **Serving Layer:** Interactive Tableau dashboards visualizing spatial surge pricing, airport connection density, and precipitation sensitivity[cite: 5].

---
## 📊 Key Analytical Findings

* **Precipitation Surges:** Rain events above 5mm showed a **~18% spike in demand** in Manhattan commercial zones, accompanied by longer wait times and higher average tip percentages.
* **Peak Bottlenecks:** Concentrated surge volume identified on Friday afternoons (4:00 PM – 8:00 PM) during adverse weather conditions[cite: 5].
* **Route Elasticity:** Airport routes (JFK / LGA) proved significantly less weather-sensitive in passenger demand than discretionary intra-borough trips.

---

## Running the dbt Project Locally

### Prerequisites
* Python 3.9+
* BigQuery project credentials (`profiles.yml`)
* dbt-core & dbt-bigquery adapter

### Execution Commands
```bash
# 1. Install dependencies
dbt deps

# 2. Run data quality and schema tests
dbt test

# 3. Build models (staging -> intermediate -> marts)
dbt run

# 4. Generate & view lineage documentation
dbt docs generate
dbt docs serve
