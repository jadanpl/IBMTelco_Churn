USE ibm_telco_churn;

-- ========== START FOR QUERY 1 ========== 
-- Considering the top 5 groups with the highest average monthly charges among churned customers, 
-- How can personalized offers be tailored based on age, gender, and contract type 
-- To potentially improve customer retention rates?
SELECT 
   CASE 
      WHEN Age < 30 THEN 'Young Adults'
      WHEN Age >= 30 AND Age < 50 THEN 'Middle-Aged Adults'
      ELSE 'Seniors'
   END AS AgeGroup,
   Contract,
   Gender,
   ROUND(AVG(`Tenure in Months`),2) AS AvgTenure,
   ROUND(AVG(`Monthly Charge`),2) AS AvgMonthlyCharge
FROM telco_churn
WHERE `Churn Label` LIKE '%Yes%'
GROUP BY AgeGroup, `Customer Status`, Contract, Gender
ORDER BY AvgMonthlyCharge DESC
LIMIT 5;
-- ========== END FOR QUERY 1 ========== 

-- ========== START OF QUERY 2 ========== 
-- What are the feedback or complaints from those churned customers?
SELECT `Churn Category`, COUNT(`Customer ID`) AS churn_count
FROM telco_churn
WHERE `Churn Label` LIKE "%Yes%"
GROUP BY `Churn Category`
ORDER BY churn_count DESC;

-- check the churn reason for the "Other" category
SELECT `Churn Category`, `Churn Reason`, COUNT(`Churn Reason`) AS churn_count
FROM telco_churn
WHERE `Churn Category` LIKE "%Other%" 
GROUP BY `Churn Reason`
ORDER BY churn_count DESC;

-- check the category for those customers who complaints about the poor expertise of online support
SELECT `Churn Category`, `Churn Reason`, COUNT(`Churn Reason`) AS churn_count
FROM telco_churn
WHERE `Churn Reason` LIKE "%Poor expertise of online support%"
GROUP BY `Churn Category`
ORDER BY churn_count DESC;

-- replace "Other" category into more meaningful categories
UPDATE telco_churn
SET `Churn Category` = 
    CASE 
        WHEN `Churn Reason` IN ('Moved', 'Deceased') THEN 'Personal Issue'
        WHEN `Churn Reason` = 'Don''t know' THEN 'Unknown'
        WHEN `Churn Reason` = 'Poor expertise of online support' THEN 'Dissatisfaction'
        ELSE `Churn Category`
    END;

-- replace the blank with 'NA' under "Churn Reason" column for loyal customers 
UPDATE telco_churn
SET `Churn Reason`="NA"
WHERE `Churn Reason` IS NULL OR `Churn Reason` = '';

-- replace the blank with 'NA' under "Churn Category" column for loyal customers 
UPDATE telco_churn
SET `Churn Category`="NA"
WHERE `Churn Category` IS NULL OR `Churn Category` = '';

-- expected output for query 2
SELECT `Churn Category`, COUNT(`Customer ID`) AS churn_count, 
		ROUND(COUNT(`Customer ID`)/7043*100,2) AS proportion_in_percent
FROM telco_churn
GROUP BY `Churn Category`
ORDER BY churn_count DESC;
-- ========== END FOR QUERY 2 ========== 

-- ========== START OF QUERY 3 ========== 
-- How does the payment method influence churn behavior?
WITH ChurnData AS (
    SELECT `Payment Method`, COUNT(`Customer ID`) AS Churned
    FROM telco_churn
    WHERE `Churn Label` LIKE '%Yes%'
    GROUP BY `Payment Method`),
LoyalData AS (
    SELECT  `Payment Method`, COUNT(`Customer ID`) AS Loyal
    FROM telco_churn
    WHERE `Churn Label` LIKE '%No%'
    GROUP BY `Payment Method`)
    
SELECT 
    a.`Payment Method`, a.Churned, b.Loyal, 
    a.Churned + b.Loyal AS total, 
    SUM(a.Churned + b.Loyal) OVER (ORDER BY a.`Payment Method`) AS running_total
FROM ChurnData a 
INNER JOIN LoyalData b
ON a.`Payment Method` = b.`Payment Method`;
-- ========== END FOR QUERY 3 ========== 
