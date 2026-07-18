-- =====================================================================
-- Student: Kashif Ahmad Abdul Jahangir
-- Batch: DA-DS-1
-- Project: RedFlag – Fraud Detection Using SQL
-- =====================================================================
USE redflag;
-- =====================================================================
-- PATTERN 1 - VELOCITY FRAUD
-- What I'm looking for: users with 30+ transactions in a single day
-- following query give you user with more than 30 transaction in single day. 
-- ===========================================================================
SELECT user_id,Date(txn_time) AS TXN_Day, count(*) AS Daily_Transaction 
FROM transactions 
GROUP BY user_id , Date(txn_time)
HAVING  count(*) > 30
ORDER BY Daily_Transaction desc;

-- My finding :  50 records where user have 30 plus transaction on same day.
-- Top 3 fraudsters by transaction count: (user=14569	date=2024-04-03	 txn=60)
-- (user=14556	date=2024-05-28	txn=60),(user=14564	date=2024-02-15	txn=59);

-- ===========================================================================================================
-- PATTERN 2 - Round Amount Clustering
-- ==========================================================================================================
SELECT user_id, count(*) AS Transfer_count FROM transactions
WHERE amount IN (100, 200, 500,1000, 2000, 5000,10000)
GROUP BY user_id
HAVING count(*) >= 15 
ORDER BY Transfer_count desc;

-- My finding : 25 rows having  15+ transaction_amount in exacct figures (₹100, ₹500, ₹1,000, ₹5,000, ₹10,000)   
-- top 3 transaction: user=14533 (30 txn)
--                    user=14534 (30 txn)
-- 					  user=14535 (30 txn)

-- ============================================================================================================
-- PATTERN 3 - Card Testing
-- =============================================================================================================
SELECT user_id,Date(txn_time) AS T_day, count(*) AS Transfer_count FROM transactions
WHERE amount <= 10
GROUP BY user_id,Date(txn_time)
HAVING count(*) >= 30 
ORDER BY Transfer_count desc;

-- My finding : 20 row where amount is less than 10 in single day 
-- top 3 users Transaction: (user_id  total_amount transafer_count)=(14556	302.53	60) (14569	323.58	60)  
-- (14559	321.75 59)

-- ============================================================================================================
-- PATTERN 4 - Failed-Then-Succeeded
-- =============================================================================================================
SELECT user_id, status,count(*) AS Failed_TXN FROM transactions
WHERE status='FAILED'
GROUP BY user_id
HAVING count(*) >= 20
ORDER BY Failed_TXN desc;

-- Advance version:

WITH txn_history AS (SELECT
user_id,
txn_time,
status,
LAG(status) over (partition by user_id ORDER BY txn_time) AS previous_status,
LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS previous_time
from transactions)
SELECT user_id,
COUNT(*) AS Failed_then_Success
FROM txn_history
WHERE status = 'SUCCESS'
  AND previous_status = 'FAILED'
  AND TIMESTAMPDIFF(MINUTE,previous_time,txn_time) <=30
GROUP BY user_id
HAVING count(*) >= 5
ORDER BY Failed_then_Success DESC;



-- My finding : 25 rows where user have Failed transaction having Transaction_count above 20;
-- top 3 highest user with failed transaction:(14595	FAILED	35) (14593	FAILED	34) (14576	FAILED	33)
-- ===============================================================================================================
-- PATTERN 5 - Odd Hour Concentration
-- ===============================================================================================================
SELECT 
user_id,
SUM(Case when hour(txn_time) BETWEEN 2 AND 4 Then 1 ELSE 0 END) AS count_odd_hour,
COUNT(*) AS Transaction_count,
(SUM(Case when hour(txn_time) BETWEEN 2 AND 4 Then 1 ELSE 0 END)*100 /count(*)) AS odd_hour_ratio
FROM transactions 
GROUP BY user_id
HAVING count(*) >=30 And
(count_odd_hour*100 /Transaction_count)>= 80 
ORDER BY odd_hour_ratio desc;

-- My finding : there is 20 rows where transaction occure betwen 2 to 4 Am
-- Top 3 users: (14606	49	52	94.2308) (14609	45	48	93.7500) (14608	58	63	92.0635) 
-- ===============================================================================================================
-- PATTERN 6 - Mule Accounts
-- ===============================================================================================================
SELECT user_id,payment_mode,txn_type,count(*) AS CR_TXN 
FROM transactions
WHERE payment_mode='NETBANKING' AND txn_type='CREDIT'
GROUP BY user_id,payment_mode
HAVING count(payment_mode)>=8
ORDER BY CR_TXN desc;

-- My finding: 30 records with having Credit money via Netbanking
-- top 3 records:(14630	NETBANKING	CREDIT	15) (14637	NETBANKING	CREDIT	15) (14640	NETBANKING	CREDIT	15)

-- ===============================================================================================================
-- Pattern 7 – Refund Abuse
-- ===============================================================================================================
SELECT user_id,
COUNT(*) AS total_transaction,
SUM(Case When txn_type='REFUND' then 1 Else 0 End) AS Refund_count,
(SUM(Case When txn_type='REFUND' then 1 Else 0 End)*100 / COUNT(*)) AS Refund_ratio
FROM Transactions
GROUP BY user_id
HAVING count(*) >= 20 
AND  Refund_ratio >= 40
ORDER BY Refund_ratio DESC;

-- My finding : there 25 records Satisfies conditons 
-- Top 3 records: (14662 39	25 64.1026) (14670	50	32	64.0000) (14665	36	23	63.8889) 
-- ===============================================================================================================
-- Pattern 8 – Merchant Collusion
-- ===============================================================================================================
-- CTE1
WITH Merchant_Transaction  AS (SELECT 
merchant_id,
user_id ,
sum(amount) AS amount_count 
FROM Transactions 
GROUP BY merchant_id,user_id
),
-- CTE2
row_numbers AS (SELECT merchant_id,
user_id,
amount_count, 
Row_number() over(partition by merchant_id order by amount_count DESC ) AS RN 
FROM Merchant_Transaction
),
-- CTE3
amount_per_merchnat AS (SELECT merchant_id,
sum(amount_count) AS top5_total FROM row_numbers
WHERE RN <= 5
GROUP BY merchant_id
),
-- CT4
Merchant_Total AS (SELECT merchant_id,
SUM(amount) AS merchant_total 
FROM transactions 
GROUP BY merchant_id
)
-- outer query
SELECT 
apm.merchant_id,apm.top5_total,
mt.merchant_total,
((apm.top5_total/mt.merchant_total)*100) as Ratio
FROM amount_per_merchnat apm
JOIN Merchant_Total mt 
ON apm.merchant_id = mt.merchant_id
WHERE ((apm.top5_total/mt.merchant_total)*100) >60;

-- My finding : There Is 15 Rows WHERE merchant have Ratio of top5 total is grater than 60%
--   top 3 : (1	1573131.69	1577167.72	99.744096) (2 1954904.43	1958233.33	99.830005) (3 1478049.01	1481098.40	99.794113)

-- ===============================================================================================================
-- Pattern 9 – Just-Under-Threshold (Structuring)
-- ===============================================================================================================
SELECT user_id,
count(*) 
FROM transactions
WHERE amount=9999
GROUP BY user_id
HAVING count(*) >= 10
ORDER BY count(*) desc;

-- My finding : There is 20 rows where users have amount = 9999 more than 10 time; 
-- Top 3 :(14680	25) (14690	25) (14693	22)

-- ===============================================================================================================
-- Pattern 10 – Dormant-Then-Active
-- ===============================================================================================================
WITH Cal_previous AS (SELECT user_id,
txn_time,
LAG(txn_time) over (partition by user_id order by txn_time) AS previous_date
FROM transactions
),

Cal_diff AS (SELECT user_id,
txn_time,
previous_date,
datediff(txn_time,previous_date) AS gap_days
FROM cal_previous
WHERE datediff(txn_time,previous_date)>=90),

Txn_cal AS (SELECT t.user_id,
count(*) AS Total_transaction
FROM transactions t 
JOIN Cal_diff c
ON t.user_id=c.user_id 
AND t.txn_time >= c.txn_time
GROUP BY t.user_id
HAVING count(*) >= 15)
SELECT user_id , Total_transaction
FROM Txn_cal;

-- My finding: 26 rows where more than 15 transaction have 90 plus days gap;
-- Top 3 : (14526  55)  (14696	24)  (14697	18)

-- ===============================================================================================================
-- Pattern 11 – Velocity Spike
-- ===============================================================================================================
with monthly_Txn as (select user_id,month(txn_time) as _month,count(*) as Total_transaction
from transactions 
group by user_id,_month),

Avg_peak_cal as (select user_id,
AVG(Total_transaction) as Avg_Monthly_Txn,
Max(Total_transaction) as Peak_Monthly_Txn
from monthly_Txn
group by user_id)

select user_id,Avg_Monthly_Txn,Peak_Monthly_Txn
from Avg_peak_cal
where  (Peak_Monthly_Txn/Avg_Monthly_Txn) >5
and Peak_Monthly_Txn >=20;

-- My finding: there is only 3 user Id who have peak monthly transaction count is at least 5x their average monthly
-- transaction count  Users: (14504	8.8333	45)  (14517	8.0000	41)  (14528	7.6667	39)

-- ===============================================================================================================
-- Pattern 12 – Geographic Impossibility
-- ===============================================================================================================
WITH cal_previous AS (SELECT 
user_id,
txn_time,
city, 
LAG(city) over (partition by user_id order by txn_time) AS previous_city,
LAG(txn_time) over (partition by user_id order by txn_time) AS previous_time
FROM transactions),

cal_diff AS (SELECT 
user_id,
txn_time,
TIMESTAMPDIFF(Minute,previous_time,txn_time) AS Time_Gap
FROM cal_previous
WHERE TIMESTAMPDIFF(Minute,previous_time,txn_time) <=60
AND previous_city <> city
)
-- use of distinct to avoid duplication of users 
SELECT 
DISTINCT user_id 
FROM cal_diff;

-- My finding: three is 15 users which are located in diffrent cities in 1 hour;

-- ===============================================================================================================
-- ===============================================================================================================
-- SUMMARY
-- ================================================================================================================ 
-- This analysis identified multiple fraud patterns using SQL.
-- Window functions, CTEs, aggregate functions, and date/time functions were used
-- to detect suspicious customer behavior.
--
-- Key observations:
-- • Velocity Fraud              : 50 suspicious user-day combinations
-- • Round Amount Clustering     : 25 users
-- • Card Testing                : 20 users
-- • Failed Transactions         : 25 users
-- • Odd Hour Concentration      : 20 users
-- • Mule Accounts               : 30 users
-- • Refund Abuse                : 25 users
-- • Merchant Collusion          : 15 merchants
-- • Structuring                 : 20 users
-- • Dormant Then Active         : 26 users
-- • Velocity Spike              : 3 users (AVG-based approach)
-- • Geographic Impossibility    : 15 users
--
-- These users and merchants should be prioritized for further fraud investigation.
-- BY analysis  top 3 Users in each patterns:
-- Cross-pattern analysis shows that User IDs 14556 and 14569 were flagged in multiple fraud detection patterns.  
-- These accounts should be prioritized for manual investigation.
-- ===============================================================================================================
