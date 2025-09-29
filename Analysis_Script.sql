
--------------------------- Exploratory Data Analysis on table 1: User_Profiles
Select * 
from brighttv.analysis.user_profiles
Limit 10;

--- Counting unique IDs = 5375
Select count (distinct USERID) AS Unique_User_Count
from brighttv.analysis.user_profiles;

---- Checking max and min age: 114, 0, 27,7
Select max (age) AS max_age, min (age) as min_age, avg(age) as avg_age
from brighttv.analysis.user_profiles;

--- How can someone be 0? :0  Looks like not all fields are filled in. Only email looks mandatory. So do I remove the people with no age group from my analysis?
select distinct(userid), name, surname, age
 from brighttv.analysis.user_profiles
  where age = 0;
  
--- Creating age buckets

SELECT 
    UserID,Name, Surname, Age,
    CASE
        WHEN Age BETWEEN 1 AND 30 THEN 'Youth'
        WHEN Age BETWEEN 31 AND 60 THEN 'Adult'
        WHEN Age BETWEEN 61 AND 90 THEN 'Elderly'
        WHEN Age BETWEEN 91 AND 120 THEN 'Senior'
        ELSE 'No Age Provided'
    END AS Age_Bucket
FROM BrightTV.Analysis.User_Profiles;


------- EDA table 2: Viewership
Select * 
FROM brighttv.analysis.viewership
Limit 10;


-- Which channel has the max duration time?


SELECT 
    channel2,
    SUM(
        CAST(LEFT(duration2, 2) AS INT) +      -- hours 
        CAST(SUBSTRING(duration2, 4, 2) AS INT) / 60+   -- minutes to hours
        CAST(RIGHT(duration2, 2) AS INT) / 3600.0     -- seconds to hours
    ) AS TotalMinutes
FROM BrightTV.Analysis.viewership
GROUP BY channel2
ORDER BY TotalMinutes DESC;


--- How many channels are there? 21
Select count (distinct channel2)
FROM BrightTV.Analysis.viewership;

--- how do I extract the day/ month from the record date?

SELECT 
  RecordDate2,
  EXTRACT(DAY FROM to_date(RecordDate2, 'yyyy/MM/dd HH:mm')) AS Day,
  EXTRACT(MONTH FROM to_date(RecordDate2, 'yyyy/MM/dd HH:mm')) AS Month,
  date_format(to_timestamp(RecordDate2, 'yyyy/MM/dd HH:mm'), 'MMMM') AS MonthName
FROM BrightTV.Analysis.viewership;



-- Combined SQL Script for Viewership Analysis

-- Viewership by Province
WITH Viewership_By_Province AS (
    SELECT 
        up.Province,
        COUNT(v.UserID) AS Viewership_Count
    FROM BrightTV.Analysis.viewership v
    JOIN BrightTV.Analysis.User_Profiles up ON v.UserID = up.UserID
    GROUP BY up.Province
),

-- Users by Race
Users_By_Race AS (
    SELECT 
        Race,
        COUNT(UserID) AS User_Count
    FROM BrightTV.Analysis.User_Profiles
    GROUP BY Race
),


-- Viewership by Race and Gender
Viewership_By_Race_Gender AS (
    SELECT 
        up.Race,
        up.Gender,
        COUNT(v.UserID) AS Viewership_Count
    FROM BrightTV.Analysis.viewership v
    JOIN BrightTV.Analysis.User_Profiles up ON v.UserID = up.UserID
    GROUP BY up.Race, up.Gender
),

-- Usage Consumption by Age Cohort
Viewership_By_Age_Cohort AS (
    SELECT
        CASE
            WHEN up.Age BETWEEN 1 AND 30 THEN 'Youth'
            WHEN up.Age BETWEEN 31 AND 60 THEN 'Adult'
            WHEN up.Age BETWEEN 61 AND 90 THEN 'Elderly'
            WHEN up.Age BETWEEN 91 AND 120 THEN 'Senior'
            ELSE 'No Age Provided'
        END AS Age_Cohort,
        COUNT(v.UserID) AS Viewership_Count
    FROM BrightTV.Analysis.viewership v
    JOIN BrightTV.Analysis.User_Profiles up ON v.UserID = up.UserID
    GROUP BY Age_Cohort
),

-- Duration Breakdown
Duration_Breakdown AS (
    SELECT 
        Channel2,
        Duration2,
        EXTRACT(SECOND FROM Duration2) AS seconds,
        EXTRACT(MINUTE FROM Duration2) AS minutes,
        EXTRACT(HOUR FROM Duration2) AS hours
    FROM brighttv.analysis.viewership
),

-- Duration in Minutes
Duration_In_Minutes AS (
    SELECT 
        Channel2,
        (EXTRACT(HOUR FROM Duration2) * 60) +
        EXTRACT(MINUTE FROM Duration2) +
        (EXTRACT(SECOND FROM Duration2) / 60.0) AS Total_Minutes
    FROM brighttv.analysis.viewership
),

-- Consumption by Race and Duration
Consumption_By_Race_Duration AS (
    SELECT
        up.Race,
        SUM(
            EXTRACT(HOUR FROM v.Duration2) * 60 +
            EXTRACT(MINUTE FROM v.Duration2) +
            EXTRACT(SECOND FROM v.Duration2) / 60.0
        ) AS Total_Minutes
    FROM brighttv.analysis.viewership v
    JOIN brighttv.analysis.user_profiles up ON v.UserID = up.UserID
    GROUP BY up.Race
),

-- Consumption by Race and Hour of Day
Consumption_By_Race_Hour AS (
    SELECT
        up.Race,
        HOUR(to_timestamp(v.RecordDate2, 'yyyy/MM/dd HH:mm')) AS Hour_Of_Day,
        SUM(
            EXTRACT(HOUR FROM v.Duration2) * 60 +
            EXTRACT(MINUTE FROM v.Duration2) +
            EXTRACT(SECOND FROM v.Duration2) / 60.0
        ) AS Total_Minutes
    FROM brighttv.analysis.viewership v
    JOIN brighttv.analysis.user_profiles up ON v.UserID = up.UserID
    GROUP BY up.Race, Hour_Of_Day
),

-- Consumption by Race and Time Bucket
Consumption_By_Race_Time_Bucket AS (
    SELECT
        up.Race,
        CASE
            WHEN HOUR(to_timestamp(v.RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 0 AND 5 THEN 'Night'
            WHEN HOUR(to_timestamp(v.RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN HOUR(to_timestamp(v.RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN HOUR(to_timestamp(v.RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Unknown'
        END AS Time_Bucket,
        SUM(
            EXTRACT(HOUR FROM v.Duration2) * 60 +
            EXTRACT(MINUTE FROM v.Duration2) +
            EXTRACT(SECOND FROM v.Duration2) / 60.0
        ) AS Total_Minutes
    FROM brighttv.analysis.viewership v
    JOIN brighttv.analysis.user_profiles up ON v.UserID = up.UserID
    GROUP BY up.Race, Time_Bucket
),

-- Daily Viewership by Day of Week
Daily_Viewership AS (
    SELECT
        date_format(to_timestamp(RecordDate2, 'yyyy/MM/dd HH:mm'), 'EEEE') AS Day_Of_Week,
        SUM(
            EXTRACT(HOUR FROM Duration2) * 60 +
            EXTRACT(MINUTE FROM Duration2) +
            EXTRACT(SECOND FROM Duration2) / 60.0
        ) AS Total_Minutes
    FROM brighttv.analysis.viewership
    GROUP BY Day_Of_Week
),

-- Time Bucket with Most Views
Time_Bucket_Views AS (
    SELECT
        Time_Bucket,
        COUNT(*) AS Viewership_Count
    FROM (
        SELECT
            CASE
                WHEN HOUR(to_timestamp(RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 0 AND 5 THEN 'Night'
                WHEN HOUR(to_timestamp(RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 6 AND 11 THEN 'Morning'
                WHEN HOUR(to_timestamp(RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 12 AND 17 THEN 'Afternoon'
                WHEN HOUR(to_timestamp(RecordDate2, 'yyyy/MM/dd HH:mm')) BETWEEN 18 AND 23 THEN 'Evening'
                ELSE 'Unknown'
            END AS Time_Bucket
        FROM brighttv.analysis.viewership
    ) AS Buckets
    GROUP BY Time_Bucket
),

-- Top 10 Content by Views
Top_Content AS (
    SELECT 
        Channel2,
        COUNT(*) AS View_Count
    FROM brighttv.analysis.viewership
    GROUP BY Channel2
    ORDER BY View_Count DESC
    LIMIT 10
)


-- Final SELECTs (export each of these separately)
SELECT * FROM Viewership_By_Province;
SELECT * FROM Users_By_Race;
SELECT * FROM Viewership_By_Race_Gender;
SELECT * FROM Viewership_By_Age_Cohort;
SELECT * FROM Duration_Breakdown;
SELECT * FROM Duration_In_Minutes;
SELECT * FROM Consumption_By_Race_Duration;
SELECT * FROM Consumption_By_Race_Hour;
SELECT * FROM Consumption_By_Race_Time_Bucket;
SELECT * FROM Daily_Viewership;
SELECT * FROM Time_Bucket_Views;
SELECT * FROM Top_Content;


