USE e_commerce

SELECT * FROM e_commerce_data

----Analyze the data by finding the answers to the questions below:-----

--1. Find the top 3 customers who have the maximum count of orders.
SELECT TOP 3 Cust_ID, Customer_Name, COUNT(DISTINCT Ord_ID) CNT_ORD 
FROM e_commerce_data 
GROUP BY Cust_ID, Customer_Name 
ORDER BY CNT_ORD DESC;

--2. Find the customer whose order took the maximum time to get shipping.
SELECT Ord_ID, Cust_ID, Customer_Name, Province, DaysTakenForShipping
FROM e_commerce_data 
ORDER BY DaysTakenForShipping DESC;

--3. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
--Total number of unique customers in January
SELECT COUNT(DISTINCT Cust_ID) AS Total_Uniq_Cust_Jnry
FROM e_commerce_data
WHERE YEAR(Order_Date) = '2011' AND MONTH(Order_Date) = 1;

--Which customers came back every month in 2011
SELECT Cust_ID, COUNT(DISTINCT MONTH(Order_Date)) AS Months_Visited
FROM e_commerce_data
WHERE YEAR(Order_Date) = '2011'
GROUP BY Cust_ID
HAVING COUNT(DISTINCT MONTH(Order_Date)) = 12;

--4. Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID.
--SOLUTION-1
SELECT Cust_ID, First_Order, Third_Order, DATEDIFF(DAY, First_Order, Third_Order) AS TimeElapsed
FROM (
    SELECT Cust_ID, Order_Date AS FIRST_ORDER, 
           LEAD(Order_Date, 2) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS Third_Order,
           ROW_NUMBER() OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS Order_Rank
    FROM e_commerce_data
) AS Ranked_Orders
WHERE Order_Rank = 1;

--We use the LEAD function with ORDER BY Order_Date to get the third order date for each customer. The LEAD(Order_Date, 2) retrieves the value from two rows ahead, which corresponds to the third order date.
-- ROW_NUMBER() function to assign a unique rank for each order date within each customer

--SOLUTION-2
SELECT Cust_ID,
       MIN(Order_Date) AS First_Order,
       MAX(CASE WHEN Order_Rank = 3 THEN Order_Date END) AS Third_Order,
       DATEDIFF(DAY, MIN(Order_Date), MAX(CASE WHEN Order_Rank = 3 THEN Order_Date END)) AS TimeElapsed
FROM (
    SELECT Cust_ID, Order_Date,
           ROW_NUMBER() OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS Order_Rank
    FROM e_commerce_data
) AS Ranked_Orders
WHERE Order_Rank <= 3
GROUP BY Cust_ID;

--SOLUTION-3
WITH cte as (
SELECT *,
	LEAD(Order_Date,2) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) third_order_day,
	DATEDIFF(DAY,Order_Date,LEAD(Order_Date,2) OVER (PARTITION BY Cust_ID ORDER BY Order_Date)) day_diff,
	ROW_NUMBER() OVER(PARTITION BY Cust_ID ORDER BY Cust_ID,Order_Date) AS nth_order
FROM
(
	SELECT DISTINCT Ord_ID,Cust_ID,Customer_Name,Order_Date				
	FROM [dbo].[e_commerce_data]
	--WHERE Cust_ID='Cust_100'
) subq
)
SELECT Ord_ID,Cust_ID,Customer_Name,Order_Date, third_order_day,day_diff 
FROM cte a
WHERE nth_order=1 AND third_order_day IS NOT NULL
ORDER BY Cust_ID


--5. Write a query that returns customers who purchased both product 11 and product 14, as well as the ratio of these products to the total number of products purchased by the customer.
SELECT Cust_ID, COUNT(Ord_ID) total_ord
FROM e_commerce_data
WHERE Prod_ID IN ('Prod_11', 'Prod_14')
GROUP BY Cust_ID
HAVING COUNT(DISTINCT Prod_ID) = 2;


SELECT Cust_ID,
       SUM(CASE WHEN Prod_ID IN ('Prod_11', 'Prod_14') THEN 1 ELSE 0 END) AS Purchased_11_14,
       COUNT(*) AS Total_Purchased,
       ROUND(SUM(CASE WHEN Prod_ID IN ('Prod_11', 'Prod_14') THEN 1 ELSE 0 END) * 1.0 / COUNT(*), 2) AS Ratio_to_Total
FROM e_commerce_data
GROUP BY Cust_ID
HAVING SUM(CASE WHEN Prod_ID = 'Prod_11' THEN 1 ELSE 0 END) > 0
   AND SUM(CASE WHEN Prod_ID = 'Prod_14' THEN 1 ELSE 0 END) > 0;

--CUSTOMER SEGMENTATION

--Categorize customers based on their frequency of visits. The following stepswill guide you. If you want, you can track your own way.

--1. Create a “view” that keeps visit logs of customers on a monthly basis. (Foreach log, three field is kept: Cust_id, Year, Month)
CREATE VIEW vw_monthly_visit_logs AS
	SELECT Cust_id, YEAR(Order_Date) AS Year, MONTH(Order_Date) AS Month
	FROM e_commerce_data;

SELECT * FROM [dbo].[vw_monthly_visit_logs]

--2. Create a “view” that keeps the number of monthly visits by users. (Showseparately all months from the beginning business)
CREATE VIEW vw_monthly_ord_num AS
	SELECT DISTINCT Cust_ID, YEAR(Order_Date) year_of_order, MONTH(Order_Date) month_of_order,
			COUNT(Order_Date) OVER(PARTITION BY Cust_ID, YEAR(Order_Date), MONTH(Order_Date)) cnt_order_per_month
	FROM e_commerce_data;

SELECT * FROM [dbo].[vw_monthly_ord_num]

--3. For each visit of customers, create the next month of the visit as a separatecolumn.
CREATE VIEW vw_next_month_visit_cust AS
	SELECT DISTINCT Cust_ID, Ord_ID,
                YEAR(Order_Date) AS year_of_order, 
                MONTH(Order_Date) AS month_of_order,
                LEAD(YEAR(Order_Date), 1) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS next_year,
                LEAD(MONTH(Order_Date), 1) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS next_month
	FROM e_commerce_data;

SELECT * FROM [dbo].[vw_next_month_visit_cust]

--4. Calculate the monthly time gap between two consecutive visits by eachcustomer.
SELECT Cust_ID, Order_Date,
       LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS Previous_Order,
       DATEDIFF(MONTH, LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date), Order_Date) AS Monthly_Time_Gap
FROM e_commerce_data; 


WITH RankedVisits AS (
    SELECT Cust_ID, Order_Date,
           ROW_NUMBER() OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS VisitRank
    FROM e_commerce_data
)
SELECT A.Cust_ID, A.Order_Date, B.Order_Date AS Previous_Visit,
       DATEDIFF(MONTH, B.Order_Date, A.Order_Date) AS Monthly_Time_Gap
FROM RankedVisits A
LEFT JOIN RankedVisits B ON A.Cust_ID = B.Cust_ID AND A.VisitRank = B.VisitRank + 1;


--5. Categorise customers using average time gaps. Choose the most fittedlabeling model for you.
SELECT Cust_ID, Order_Date,
           LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS Previous_Visit,
           DATEDIFF(MONTH, LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date), Order_Date) AS Monthly_Time_Gap
FROM e_commerce_data
ORDER BY Monthly_Time_Gap DESC;

SELECT DISTINCT DATEDIFF(MONTH, LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date), Order_Date) AS Monthly_Time_Gap
FROM e_commerce_data
ORDER BY Monthly_Time_Gap DESC;
--Max value of Monthly_Time_Gap is 45
--Min value of Monthly_Time_Gap is 0

WITH RankedVisits AS (
    SELECT Cust_ID, Order_Date,
           LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS Previous_Visit,
           DATEDIFF(MONTH, LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date), Order_Date) AS Monthly_Time_Gap
    FROM e_commerce_data
)
SELECT Cust_ID, 
       AVG(Monthly_Time_Gap) AS Avg_Time_Gap,
       CASE
           WHEN AVG(Monthly_Time_Gap) < 4 THEN 'More Frequent'
		   WHEN AVG(Monthly_Time_Gap) < 8 THEN 'Frequent'
		   WHEN AVG(Monthly_Time_Gap) < 15 THEN 'Regular'
		   WHEN AVG(Monthly_Time_Gap) < 25 THEN 'Irregular'
           WHEN AVG(Monthly_Time_Gap) < 35 THEN 'Less Frequent'
		   WHEN AVG(Monthly_Time_Gap) IS NULL THEN 'Just 1 order'
           ELSE 'Much Less Frequent'
       END AS Category
FROM RankedVisits
GROUP BY Cust_ID, Monthly_Time_Gap;


--Month-Wise Retention Rate
--Find month-by-month customer retention ratei since the start of the business.

--1. Find the number of customers retained month-wise. (You can use time gaps)

CREATE VIEW vw_monthly_retention AS
	SELECT VW1.year_of_order, VW1.month_of_order, 
		   COUNT(DISTINCT VW1.Cust_ID) AS retained_customers
	FROM [dbo].[vw_next_month_visit_cust] VW1
	LEFT JOIN [dbo].[vw_next_month_visit_cust] VW2 
		ON VW1.Cust_ID = VW2.Cust_ID
	   AND VW1.year_of_order = VW2.next_year
	   AND VW1.month_of_order = VW2.next_month
	GROUP BY VW1.year_of_order, VW1.month_of_order;

--In above, i find the unique customers which are retained in each month

SELECT * FROM [dbo].[vw_monthly_retention]

--2. Calculate the month-wise retention rate.
CREATE VIEW vw_monthly_retention_rate AS
SELECT VW1.year_of_order, VW1.month_of_order, VW1.retained_customers, T1.total_customers,
       CAST((1.0 * VW1.retained_customers / T1.total_customers) AS DECIMAL(10,2))  AS retention_rate
FROM vw_monthly_retention VW1
JOIN (
    SELECT year_of_order, month_of_order, 
           COUNT(Cust_ID) AS total_customers
    FROM vw_next_month_visit_cust
    GROUP BY year_of_order, month_of_order
) T1 ON VW1.year_of_order = T1.year_of_order AND VW1.month_of_order = T1.month_of_order;

SELECT * FROM [dbo].[vw_monthly_retention_rate]