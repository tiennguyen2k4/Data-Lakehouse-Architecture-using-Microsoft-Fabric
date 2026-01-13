USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_fact_budget
    @etl_date DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);


    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'fact_budget' AND layer_type = 'gold';

    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#fact_budget_stg') IS NOT NULL
        DROP TABLE #fact_budget_stg;

    SELECT
        c.account_key,
        dep.department_key,
        d.date_key AS budget_date_key,
        b.budget,
        b.modified_date
    INTO #fact_budget_stg
    FROM DATN_Silver_WH.dbo.budget b
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d
        ON d.[date] = b.budget_date
    LEFT JOIN DATN_Gold_WH.dbo.dim_account c
        ON c.account_key = b.account_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_department dep
        ON dep.department_key = b.department_id
  
    WHERE b.modified_date > @MaxModifiedDate;


    MERGE INTO DATN_Gold_WH.dbo.fact_budget AS target
    USING #fact_budget_stg AS source
    ON target.account_key = source.account_key
       AND target.department_key = source.department_key
       AND target.budget_date_key = source.budget_date_key  

    WHEN MATCHED THEN
        UPDATE SET
            target.budget = source.budget,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            account_key,
            department_key,
            budget_date_key,
            budget,
            modified_date
        )
        VALUES (
            source.account_key,
            source.department_key,
            source.budget_date_key,
            source.budget,
            source.modified_date
        );

 
    SELECT @rows_changed = @@ROWCOUNT;

  
    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #fact_budget_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_budget' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'fact_budget' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_budget', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #fact_budget_stg;

END;
GO

-- EXEC dbo.sp_iload_fact_budget