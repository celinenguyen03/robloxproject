-- Select data that we are going to use

SELECT *
FROM RobloxProject..BigRobloxGames
ORDER BY 3 DESC

SELECT *
FROM RobloxProject..SmallRobloxGames
ORDER BY 3 DESC

-- Normalize the dates so that they're all the same (YYYY-MM-DD)

UPDATE RobloxProject..BigRobloxGames
SET Date = CONVERT(DATE, Date)

-- Create a View to see the average amount of users per game

CREATE VIEW AvgActiveUsers AS
WITH RankedGames AS (
    SELECT
        [Date Created],
        Genre,
        Title,
        gameID,
        [Total Visits],
        ROUND(AVG([Active Users]) OVER (PARTITION BY gameID), 0) AS [Average Active Users],
        ROW_NUMBER() OVER (PARTITION BY gameID ORDER BY [Total Visits] DESC) AS rn
    FROM
        RobloxProject..BigRobloxGames
),
MaxVisits AS (
    SELECT
        [Date Created],
        Genre,
        gameID,
        MAX([Total Visits]) AS [Total Visits],
        [Average Active Users],
        MIN(Title) AS Title
    FROM
        RankedGames
    GROUP BY
        gameID, [Average Active Users], [Date Created], Genre
)
SELECT
    [Date Created],
    Genre,
    Title,
    gameID,
    [Total Visits],
    [Average Active Users]
FROM
    MaxVisits

-- View new table

SELECT [Date Created]
      ,[Genre]
      ,[Title]
      ,[gameID]
      ,[Total Visits]
      ,[Average Active Users]
  FROM [RobloxProject].[dbo].[AvgActiveUsers]
  ORDER BY 6 DESC

-- Create a View to see the changes in visitors over time

CREATE VIEW GameUpdatesTrends AS
WITH ParsedVisits AS (
    SELECT
        gameID,
        [Genre],
        [Title],
        TRY_CONVERT(DATE, [Last Updated]) AS LastUpdatedDate,
        [Last Updated],
        [Active Users],
        [Favorites],
        CASE
            WHEN [Total Visits] LIKE '%B%' THEN CAST(REPLACE(REPLACE([Total Visits], 'B', ''), '+', '') AS FLOAT) * 1000000000
            WHEN [Total Visits] LIKE '%M%' THEN CAST(REPLACE(REPLACE([Total Visits], 'M', ''), '+', '') AS FLOAT) * 1000000
            WHEN ISNUMERIC(REPLACE(REPLACE([Total Visits], '+', ''), '.', '')) = 1 THEN CAST(REPLACE(REPLACE([Total Visits], '+', ''), '.', '') AS FLOAT)
            ELSE NULL
        END AS NumericTotalVisits,
        LAG([Active Users], 1, NULL) OVER (PARTITION BY gameID ORDER BY TRY_CONVERT(DATE, [Last Updated])) AS PrevActiveUsers,
        LAG([Favorites], 1, NULL) OVER (PARTITION BY gameID ORDER BY TRY_CONVERT(DATE, [Last Updated])) AS PrevFavorites,
        LAG(CASE
            WHEN [Total Visits] LIKE '%B%' THEN CAST(REPLACE(REPLACE([Total Visits], 'B', ''), '+', '') AS FLOAT) * 1000000000
            WHEN [Total Visits] LIKE '%M%' THEN CAST(REPLACE(REPLACE([Total Visits], 'M', ''), '+', '') AS FLOAT) * 1000000
            WHEN ISNUMERIC(REPLACE(REPLACE([Total Visits], '+', ''), '.', '')) = 1 THEN CAST(REPLACE(REPLACE([Total Visits], '+', ''), '.', '') AS FLOAT)
            ELSE NULL
        END, 1, NULL) OVER (PARTITION BY gameID ORDER BY TRY_CONVERT(DATE, [Last Updated])) AS PrevTotalVisits
    FROM
        RobloxProject..BigRobloxGames
),
RankedUpdates AS (
    SELECT
        gameID,
        LastUpdatedDate,
        ROUND(AVG([Active Users]), 0) AS AvgActiveUsers,
        ROUND(AVG([Favorites]), 0) AS AvgFavorites,
        ROUND(AVG(NumericTotalVisits), 0) AS AvgTotalVisits,
        MIN([Genre]) AS Genre,
        MIN([Title]) AS Title
    FROM
        ParsedVisits
    GROUP BY
        gameID, LastUpdatedDate
),
FinalUpdates AS (
    SELECT
        gameID,
        Genre,
        Title,
        LastUpdatedDate,
        AvgActiveUsers,
        AvgFavorites,
        AvgTotalVisits
    FROM
        RankedUpdates
)
SELECT * FROM FinalUpdates;

-- View new table

SELECT
    gameID,
    Genre,
    Title,
    [LastUpdatedDate],
    AvgActiveUsers,
    AvgFavorites,
    AvgTotalVisits
FROM
    RobloxProject.dbo.GameUpdatesTrends
ORDER BY
    gameID ASC, [LastUpdatedDate] ASC;
