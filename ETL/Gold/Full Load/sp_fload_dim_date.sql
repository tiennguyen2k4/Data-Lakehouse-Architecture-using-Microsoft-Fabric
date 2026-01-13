USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_dim_date
    @etl_date DATETIME = NULL,
    @start_date DATE = NULL,
    @end_date DATE = NULL
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @current_date DATE;

    IF @etl_date IS NULL SET @etl_date = FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss');
    IF @start_date IS NULL SET @start_date = '2000-01-01';
    IF @end_date IS NULL SET @end_date = '2100-12-31';
    SET @current_date = @start_date;

    DELETE dbo.dim_date
    WHERE [date] >= @start_date AND [date] <= @end_date

    ;WITH
    t0(i) AS (SELECT 0 UNION ALL SELECT 0), 
    t1(i) AS (SELECT 0 FROM t0 a, t0 b),    
    t2(i) AS (SELECT 0 FROM t1 a, t1 b),    
    t3(i) AS (SELECT 0 FROM t2 a, t2 b),    
    t4(i) AS (SELECT 0 FROM t3 a, t3 b),    
    n(i) AS (SELECT ROW_NUMBER() OVER(ORDER BY i) - 1 FROM t4),
    d AS (
        SELECT i, DATEADD(DAY, i, @start_date) AS [date]
        FROM n
        WHERE i <= DATEDIFF(DAY, @start_date,  @end_date)
    )

    INSERT INTO dbo.dim_date
    SELECT date_key = YEAR([date]) * 10000 + MONTH([date]) * 100 + DAY([date]),
    date = [date],
    day = DAY([date]),
    day_of_week = DATEPART(DW, [date]), -- Sunday: 1, Monday: 2, ...,
    day_of_week_name = DATENAME(DW, [date]),
    day_of_week_short_name = LEFT(DATENAME(DW, [date]), 3),
    day_of_week_first_letter = LEFT(DATENAME(DW, [date]), 1),
    day_of_year = DATEDIFF(DAY, DATEADD(YEAR, DATEDIFF(YEAR, 0, [date]), 0), [date]) + 1,
    -- leap week calendar system
    iso_week = DATEPART(ISO_WEEK,[date]),
    iso_year = YEAR(DATEADD(DAY, 26 - DATEPART(ISO_WEEK, [date]), [date])),
    iso_year_week = CONCAT(YEAR(DATEADD(DAY, 26 - DATEPART(ISO_WEEK, [date]), [date])), '-', DATEPART(ISO_WEEK,[date])),
    -- month
    month = MONTH([date]),
    month_name = DATENAME(MONTH, [date]),
    month_short_name = LEFT(DATENAME(MONTH, [date]), 3),
    -- quarter
    quarter=DATEPART(QUARTER, [date]),
    quarter_name =
    CASE
        WHEN DATEPART(QUARTER, [date]) = 1 THEN 'I'
        WHEN DATEPART(QUARTER, [date]) = 2 THEN 'II'
        WHEN DATEPART(QUARTER, [date]) = 3 THEN 'III'
        WHEN DATEPART(QUARTER, [date]) = 4 THEN 'IV'
    END,
    -- year
    year=YEAR([date]),
    year_month=FORMAT([date],'yyyy-MM'),
    year_quarter = CONCAT(year([date]),'-',
    CASE
        WHEN DATEPART(QUARTER, [date]) = 1 THEN 'I'
        WHEN DATEPART(QUARTER, [date]) = 2 THEN 'II'
        WHEN DATEPART(QUARTER, [date]) = 3 THEN 'III'
        WHEN DATEPART(QUARTER, [date]) = 4 THEN 'IV'
    END),
    -- date
    first_date_of_month = DATEFROMPARTS(YEAR([date]), MONTH([date]), 1),
    last_date_of_month = EOMONTH([date]),
    first_date_of_quarter = DATEADD(QUARTER, DATEDIFF(QUARTER, 0, [date]), 0),
    last_date_of_quarter = DATEADD (DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, [date]) + 1, 0)),
    first_date_of_year = DATEFROMPARTS(YEAR([date]), 1 , 1),
    last_date_of_year = DATEFROMPARTS(YEAR([date]), 12 , 31),
    nb_days_of_month = DAY(EOMONTH([date])),
    is_leap_year = IIF(DAY(EOMONTH(DATEFROMPARTS(YEAR([date]), 2, 1))) = 29, 1, 0)
    FROM d
END

-- exec dbo.sp_fload_dim_date @start_date = '1900-01-01', @end_date = '1999-12-31'
-- exec dbo.sp_fload_dim_date @start_date = '1900-01-01', @end_date = '2100-12-31'