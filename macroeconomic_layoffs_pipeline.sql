-- PROJECT: The Cost of Capital: Correlating Federal Interest Rates and Global Layoffs
-- AUTHOR: Julian Gomez
-- DATABASE ENVIRONMENT: MySQL
-- DESCRIPTION: An end-to-end data pipeline executing data cleaning, 
--              type normalization, and advanced exploratory data analysis 
--              correlating 2020-2023 layoff velocity with Federal Reserve rates.


-- PART 1: DATA CLEANING & ENVIRONMENT STAGING

-- STEP 1.1: Create an initial staging table to protect raw source data
CREATE TABLE layoff_staging LIKE layoffs_data;
INSERT INTO layoff_staging SELECT * FROM layoffs_data;

-- STEP 1.2: Create a secondary staging table with an added row identifier column
-- This enables safe identification and removal of duplicate records.
CREATE TABLE `layoff_staging2` (
  `company` varchar(255) DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `industry` varchar(255) DEFAULT NULL,
  `total_laid_off` varchar(50) DEFAULT NULL,
  `percentage_laid_off` varchar(50) DEFAULT NULL,
  `date` varchar(50) DEFAULT NULL,
  `stage` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `funds_raised_millions` varchar(50) DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Populate secondary staging table with computed window rankings
INSERT INTO layoff_staging2
SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, 
                     percentage_laid_off, `date`, stage, country, funds_raised_millions
    ) AS row_num
FROM layoff_staging;

-- Remove absolute duplicate records (where row_num > 1)
DELETE FROM layoff_staging2 WHERE row_num > 1;


-- PART 2: DATA STANDARDIZATION & QUALITY ENGINEERING

-- STEP 2.1: String Cleaning (Trimming structural whitespaces and trailing anomalies)
UPDATE layoff_staging2 SET company = TRIM(company);

UPDATE layoff_staging2 
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- STEP 2.2: Standardize structural naming conventions across industries
UPDATE layoff_staging2 SET industry = 'Crypto' WHERE industry LIKE 'Cryoto%';
UPDATE layoff_staging2 SET industry = NULL WHERE industry = '';

-- STEP 2.3: Reconcile and populate missing industry values using self-joins
UPDATE layoff_staging2 t1
JOIN layoff_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL AND t2.industry IS NOT NULL;

-- STEP 2.4: Clean funding anomalies and cast column schemas to proper structural types
UPDATE layoff_staging2 SET funds_raised_millions = NULL WHERE funds_raised_millions LIKE 'N%';

ALTER TABLE layoff_staging2 MODIFY COLUMN `total_laid_off` INT;
ALTER TABLE layoff_staging2 MODIFY COLUMN `funds_raised_millions` INT;

-- STEP 2.5: Standardize temporal elements from text to native DATE formats
UPDATE layoff_staging2 SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');
ALTER TABLE layoff_staging2 MODIFY COLUMN `date` DATE;

-- STEP 2.6: Prune uninformative metadata records and operational utility columns
DELETE FROM layoff_staging2 WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;
ALTER TABLE layoff_staging2 DROP COLUMN row_num;


-- PART 2.5: MACROINDICATOR INGESTION & DATE STRUCTURING (FRED DATA)

-- STEP 1: Safely clear out any previous database iterations
DROP TABLE IF EXISTS fed_interest_rates;

-- STEP 2: Re-create and transform the FRED staging data.
-- This strips the daily 'YYYY-MM-DD' structure from the wizard import down to a 
-- standardized 'YYYY-MM' format to facilitate a clean table join.
CREATE TABLE fed_interest_rates AS
SELECT 
    SUBSTRING(observation_date, 1, 7) AS `month_year`,
    FEDFUNDS AS interest_rate
FROM fed_rates_staging;

-- STEP 3: Quality assurance check to verify operational alignment
SELECT * FROM fed_interest_rates LIMIT 5;


-- PART 3: EXPLORATORY DATA ANALYSIS (CORE DIMENSIONAL METRICS)

-- Descriptive range constraints
SELECT MAX(total_laid_off), MAX(percentage_laid_off) FROM layoff_staging2;
SELECT MIN(`date`), MAX(`date`) FROM layoff_staging2;

-- Total workforce impact isolated by key dimensions
SELECT company, SUM(total_laid_off) FROM layoff_staging2 GROUP BY company ORDER BY 2 DESC;
SELECT country, SUM(total_laid_off) FROM layoff_staging2 GROUP BY country ORDER BY 2 DESC;
SELECT stage, SUM(total_laid_off) FROM layoff_staging2 GROUP BY stage ORDER BY 2 DESC;
SELECT YEAR(`date`), SUM(total_laid_off) FROM layoff_staging2 GROUP BY YEAR(`date`) ORDER BY 1 DESC;

-- Tracking workforce contraction timelines by entity and annualized volumes
SELECT company, YEAR(`date`), SUM(total_laid_off) FROM layoff_staging2 GROUP BY company, YEAR(`date`) ORDER BY 3 DESC;

-- Advanced Window Function: Monthly cumulative rolling total of global layoffs
WITH Rolling_total AS (
    SELECT SUBSTRING(`date`, 1, 7) AS `MONTH`, SUM(total_laid_off) AS total_off
    FROM layoff_staging2
    WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
    GROUP BY `MONTH`
)
SELECT `MONTH`, total_off,
       SUM(total_off) OVER(ORDER BY `MONTH`) AS rolling_total
FROM Rolling_Total
ORDER BY 1 ASC;

-- Advanced Window Function: Isolate the top 5 hardest-hit companies per calendar year
WITH Company_Year (company, years, total_laid_off) AS (
    SELECT company, YEAR(`date`), SUM(total_laid_off)
    FROM layoff_staging2
    GROUP BY company, YEAR(`date`)
), 
Company_Year_Rank AS (
    SELECT *, 
           DENSE_RANK() OVER(PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
    FROM Company_Year
    WHERE years IS NOT NULL
)
SELECT * FROM Company_Year_Rank WHERE Ranking <= 5;

-- PART 4: MACROECONOMIC SENSITIVITY & BUSINESS INTELLIGENCE

-- ANALYSIS 4.1: Timeline Correlation (Monthly Layoff vs. FEDFUNDS Rate)
WITH Monthly_Layoff_Metrics AS (
    SELECT 
        SUBSTRING(`date`, 1, 7) AS `month_year`, 
        SUM(total_laid_off) AS total_global_layoffs,
        SUM(CASE WHEN country = 'United States' THEN total_laid_off ELSE 0 END) AS us_layoffs,
        SUM(CASE WHEN country != 'United States' THEN total_laid_off ELSE 0 END) AS international_layoffs,
        COUNT(DISTINCT company) AS companies_laying_off
    FROM layoff_staging2
    WHERE `date` IS NOT NULL
    GROUP BY `month_year`
)
SELECT 
    l.`month_year`,
    r.interest_rate AS fed_funds_rate,
    l.total_global_layoffs,
    l.us_layoffs,
    l.international_layoffs,
    l.companies_laying_off
FROM Monthly_Layoff_Metrics l
JOIN fed_interest_rates r 
    ON l.`month_year` = r.`month_year`
ORDER BY l.`month_year` ASC;

-- ANALYSIS 4.2: Cross-Industry Contraction Growth Rates
WITH Industry_Rate_Direct_Check AS (
    SELECT 
        l.industry,
        -- Era 1: Cheap Borrowing Era (FEDFUNDS <= 0.25%)
        SUM(CASE WHEN r.interest_rate <= 0.25 THEN l.total_laid_off ELSE 0 END) AS cheap_money_layoffs,
        -- Era 2: Expensive Borrowing Era (FEDFUNDS > 0.25%)
        SUM(CASE WHEN r.interest_rate > 0.25 THEN l.total_laid_off ELSE 0 END) AS high_rate_layoffs
    FROM layoff_staging2 l
    JOIN fed_interest_rates r 
        ON SUBSTRING(l.`date`, 1, 7) = r.`month_year`
    WHERE l.industry IS NOT NULL
    GROUP BY l.industry
)
SELECT 
    industry,
    cheap_money_layoffs,
    high_rate_layoffs,
    (high_rate_layoffs - cheap_money_layoffs) AS layoff_increase,
    ROUND(((high_rate_layoffs - cheap_money_layoffs) / NULLIF(cheap_money_layoffs, 0)) * 100, 2) AS percentage_growth
FROM Industry_Rate_Direct_Check
ORDER BY high_rate_layoffs DESC
LIMIT 5;

SELECT *
FROM layoff_staging2
WHERE industry = "Other";


