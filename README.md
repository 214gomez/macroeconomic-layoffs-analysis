# Macroeconomic-Layoffs-Analysis
An exploratory data analysis (EDA) pipeline correlating global corporate downsizings with Federal Reserve monetary tightening policies.

# The Cost of Capital: A SQL & Tableau Analysis of Global Layoffs
**Author:** Julian Gomez
**Environment:** MySQL, Tableau, Excel
**Project Type:** End-to-End ETL Pipeline & Exploratory Data Analysis (EDA)

## Executive Summary & Core Insights
This project challenges the widely accepted narrative that the 2022-2023 workforce contractions were strictly an isolated "tech bubble" bursting. By engineering a multi-source data pipeline, this analysis correlates global corporate layoffs with the Federal Reserve's monetary tightening policies to prove a broader macroeconomic thesis: **The layoff wave was systemic and cross-industry triggered by the rising cost of borrowing.**

<img width="972" height="718" alt="TimeLine Chart Screenshot 2026-05-28 at 8 45 18 PM" src="https://github.com/user-attachments/assets/4148d714-a5c5-4fe7-b410-e33d0c3aaaa4" />


### Key Findings:
1. **The Lag Effect:** The data reveals a distinct 3-to-4 month operational lag between the initial, aggressive Federal Funds Rate hikes (early 2022) and the explosion of corporate downsizings. 
2. **Capital Dependency Over Sector:** The hardest-hit companies were not strictly in the technology sector, but rather those operating in highly capital-intensive industries that relied on cheap debt to fund operations and expansion.

---

## Cross-Industry Era Sensitivity Results
To prove this was not solely a tech-sector event, I analyzed the percentage increase in layoffs by industry, explicitly isolating the era of aggressive Fed Rate hikes (> 0.25%) against the baseline "cheap money" era (<= 0.25%).

<img width="1191" height="723" alt="Industry Bar Chart Screenshot 2026-05-30 at 4 05 51 PM" src="https://github.com/user-attachments/assets/a9a4b755-d8cf-40a7-a138-af37d67b61c5" />


> ** A Note on Sector Classification:** The massive **3,126% spike** in the "Other" category was investigated by auditing the raw source dataset. This category primarily functioned as a catch-all for **Enterprise Software and B2B SaaS** giants (e.g., Atlassian, Autodesk, Asana). This massive contraction reflects how rapidly corporate clients froze their enterprise software budgets in response to rising borrowing costs, triggering downstream layoffs for B2B vendors.

---

## Tools & Technical Implementation
This project is powered by a fully custom SQL pipeline built in **MySQL**, utilizing advanced relational database techniques to ingest, standardize, and merge disjointed datasets.

* **Data Engineering (ETL):** Created a reproducible pipeline to ingest raw global layoff data alongside a secondary Federal Reserve (FRED) macro-indicator dataset.
* **Data Cleaning & Standardization:** Handled `NULL` values, standardized text formats using `TRIM()` and `SUBSTRING()`, managed duplicate records using CTEs and `ROW_NUMBER()`, and unified disparate date formats using `STR_TO_DATE()`.
* **Business Logic & Joins:** Utilized `CASE` statements to segment temporal eras (Low-Cost vs. Tightening cycles) and executed complex `JOIN` operations to merge workforce data with federal interest rate metrics on a rolling `month_year` basis.
* **Data Visualization:** Exported clean, processed tables into **Tableau** to design dual-axis and comparative bar charts, applying professional contrast formatting to highlight key business narratives.
* **AI Intergration:** Utilized Generative AI as a pair-programming tool to debug SQL syntax, refine formatting, and accelrate documentation drafting, maximizing overall project efficiency..

---

## Repository Navigation
* `macroeconomic_layoffs_pipeline.sql`: The master SQL script containing all data cleaning, staging, and analytical queries.
* `data/`: Contains the raw `.csv` files (Global Layoffs and FRED Interest Rates) used to build the SQL relational database.

---

## Data Limitations & Assumptions
To ensure analytical transparency, the following constraints were considered:
* **Reporting Bias:** The layoffs dataset relies on public reporting and WARN notices. Smaller private downsizings may be underrepresented, meaning true total layoffs are likely higher than the aggregate totals.
* **Macro Lag Operations:** The analysis assumes a standard 60-to-90 day enterprise lag coefficient between federal rate hikes and the execution of structural workforce reductions.
* **Survivorship/M&A Bias:** Companies that went completely bankrupt or were acquired during the tightening cycle may have their final workforce reductions categorized differently than standard operational layoffs.
