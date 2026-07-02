USE ibm_telco_churn;

-- Churn & Service Bundles
WITH ChurnSegment AS(
SELECT `Contract`,`Internet Type`,`Unlimited Data`,`Total Revenue`,
    SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END) AS ChurnedCustomer
FROM telco_churn
WHERE `Churn Label`="Yes" AND `Internet Type`!="None"
GROUP BY `Contract`, `Internet Type`,`Unlimited Data`)

SELECT `Contract`,`Internet Type`,`Unlimited Data`, `Total Revenue`, ChurnedCustomer, rn_churn,rn_revenue
FROM (
	SELECT `Contract`,`Internet Type`,`Unlimited Data`, `Total Revenue`,ChurnedCustomer, 
    ROW_NUMBER() OVER(PARTITION BY `Contract` ORDER BY ChurnedCustomer DESC) AS rn_churn,
	ROW_NUMBER() OVER (PARTITION BY `Contract` ORDER BY`Total Revenue` DESC) AS rn_revenue
	FROM ChurnSegment) AS ranked
WHERE rn_churn=1 OR rn_revenue=1;


/*SELECT `Contract`,`Internet Type`,`Unlimited Data`,
	SUM(CASE WHEN `Online Security`="Yes" THEN 1 ELSE 0 END) AS `Online Security`,
	SUM(CASE WHEN `Online Backup`="Yes" THEN 1 ELSE 0 END) AS `Online Backup`,
	SUM(CASE WHEN `Device Protection Plan`="Yes" THEN 1 ELSE 0 END) AS `Device Protection`,
	SUM(CASE WHEN `Premium Tech Support`="Yes" THEN 1 ELSE 0 END) AS `Premium Tech Support`,
	SUM(CASE WHEN `Streaming TV`="Yes" THEN 1 ELSE 0 END) AS `Streaming TV`,
    SUM(CASE WHEN `Streaming Music`="Yes" THEN 1 ELSE 0 END) AS `Streaming Music`,
    SUM(CASE WHEN `Streaming Movies`="Yes" THEN 1 ELSE 0 END) AS `Streaming Movies`,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END) AS ChurnedCustomer
FROM telco_churn
GROUP BY `Contract`, `Internet Type`,`Unlimited Data` WITH ROLLUP
HAVING 
	(`Contract` IS NOT NULL AND `Internet Type` IS NOT NULL AND `Unlimited Data` IS NOT NULL)
    OR 
    (`Contract` IS NULL AND `Internet Type` IS NULL AND `Unlimited Data` IS NULL)
ORDER BY ChurnedCustomer;*/

SELECT 
    `Online Security`,
    `Online Backup`,
    `Device Protection Plan`,
    `Premium Tech Support`,
    `Streaming TV`,
    `Streaming Movies`,
    `Streaming Music`,
    SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END) AS ChurnedCustomers,
    SUM(CASE WHEN `Contract`="Month-to-Month" THEN 1 ELSE 0 END) AS Month_to_Month,
    SUM(CASE WHEN `Contract`="One Year" THEN 1 ELSE 0 END) AS One_Year,
    SUM(CASE WHEN `Contract`="Two Year" THEN 1 ELSE 0 END) AS Two_Year
FROM telco_churn
WHERE `Internet Type`="Fiber Optic" AND `Unlimited Data`="Yes" AND `Churn Label`="Yes"
GROUP BY 
    `Online Security`,
    `Online Backup`,
    `Device Protection Plan`,
    `Premium Tech Support`,
    `Streaming TV`,
    `Streaming Movies`,
    `Streaming Music`
HAVING ChurnedCustomers>=20
ORDER BY ChurnedCustomers DESC;

-- Revenue vs. Satisfaction
WITH revenue_rank AS(
	SELECT `Customer ID`,`Churn Category`,`Churn Reason`,`Total Revenue`,`Satisfaction Score`,`Churn Label`,
    PERCENT_RANK() OVER(ORDER BY `Total Revenue` DESC) AS pct_rank
    FROM telco_churn)

SELECT
	CASE WHEN pct_rank>=0.9 THEN "Top 10% Cust" ELSE "Others" END AS CustGroup,
    ROUND(AVG(`Total Revenue`),2) AS AvgRevenue,
    ROUND(AVG(`Satisfaction Score`),2) AS AvgSats,
    ROUND(AVG(CASE WHEN `Churn Label`='Yes' THEN 1 ELSE 0 END)*100,2) AS `ChurnRate(%)`, 
    COUNT(*) AS Total_Cust,
    SUM(CASE WHEN `Churn Label`='Yes' THEN 1 ELSE 0 END) AS Churned_Cust,
    ROUND(SUM((`Total Revenue` - stats.AvgRevenue) * (`Satisfaction Score` - stats.AvgSats)) /
    (SQRT(SUM(POWER(`Total Revenue` - stats.AvgRevenue,2))) * SQRT(SUM(POWER(`Satisfaction Score` - stats.AvgSats,2)))),2) AS Correlation
FROM revenue_rank
CROSS JOIN(
	SELECT
		AVG(`Total Revenue`) AS AvgRevenue,
        AVG(`Satisfaction Score`) AS AvgSats
	FROM revenue_rank) stats
GROUP BY CustGroup;

-- Location-Driven Churn
WITH location_zip AS(
	SELECT `City`,`Zip Code`,`Population`,`Churn Category`,`Churn Label`
    FROM telco_churn)

SELECT 
	`City`,`Zip Code`,`Population`,
	SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END) AS 'NumofChurnedCusts',
    ROUND(SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END)/`Population`*100,2) AS 'Churned_Population(%)',
    SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END)/TC.Total_Chruned AS 'ProportionofChurned',
	SUM(CASE WHEN `Churn Category`="Competitor" THEN 1 ELSE 0 END) AS 'Competitors',
    SUM(CASE WHEN `Churn Category`="Dissatisfaction" THEN 1 ELSE 0 END) AS 'Dissatisfaction',
    SUM(CASE WHEN `Churn Category`="Price" THEN 1 ELSE 0 END) AS 'Price',
    SUM(CASE WHEN `Churn Category`="Unknown" THEN 1 ELSE 0 END) AS 'Unknown',
    SUM(CASE WHEN `Churn Category`="Attitude" THEN 1 ELSE 0 END) AS 'Attitude',
    SUM(CASE WHEN `Churn Category`="Personal Issue" THEN 1 ELSE 0 END) AS 'Personal Issue'
FROM location_zip
CROSS JOIN(
SELECT 
	SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END) AS Total_Chruned
FROM location_zip
) AS TC
WHERE `Churn Label`="Yes"  
GROUP BY `City`,`Zip Code` 
HAVING `NumofChurnedCusts`>=15 
ORDER BY `NumofChurnedCusts` DESC;

-- Referral Effectiveness
SELECT DISTINCT `Number of Referrals` FROM telco_churn;
SELECT 
	CASE WHEN `Number of Referrals`!=0 THEN "Referrals" ELSE "Non-Referrals" END AS `Categories`,
    COUNT(`Customer ID`) AS "NumofCusts",
    AVG(`Satisfaction Score`) AS AvgSats,
    AVG(`Tenure in Months`) AS AvgTenure,
    SUM(CASE WHEN `Churn Label`="Yes" THEN 1 ELSE 0 END) AS "NumofChurned"
FROM telco_churn
GROUP BY `Categories`;

-- Competitor-Driven Churn
SELECT 
	CASE 
		WHEN `Age` <=30 THEN "Young Adult (At Most 30 Y/O)"
        WHEN `Age` >30 AND `Age` <=50 THEN "Middle-Aged Adult (31-50 Y/O)"
		ELSE "Seniors (At Least 51 Y/O)"
	END AS `Age Group`,
    ROUND(AVG(CASE WHEN `Internet Type`="Fiber Optic" THEN `Monthly Charge` END),2) AS `Fiber Optic`,
    ROUND(AVG(CASE WHEN `Internet Type`="Cable" THEN `Monthly Charge` END),2) AS `Cable`,
    ROUND(AVG(CASE WHEN `Internet Type`="DSL" THEN `Monthly Charge` END),2) AS `DSL`,
    ROUND(AVG(CASE WHEN `Internet Type`="None" THEN `Monthly Charge` END),2) AS `None`
FROM telco_churn
WHERE `Churn Label`="Yes"
GROUP BY `Age Group`;