USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_fact_opportunity
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
    WHERE table_name = 'fact_opportunity' AND layer_type = 'gold';

    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#fact_opportunity_stg') IS NOT NULL
        DROP TABLE #fact_opportunity_stg;

    SELECT
        o.opportunity_key,
        o.opportunity_id,
        c.customer_key,  
        o.opportunity_stage,
        o.estimated_value,
        d.date_key AS close_date_key,  
        o.modified_date
    INTO #fact_opportunity_stg
    FROM DATN_Silver_WH.crm.opportunity o
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d
        ON d.[date] = o.close_date
    LEFT JOIN DATN_Gold_WH.dbo.dim_customer c
        ON c.customer_key = o.customer_id  
    WHERE o.modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.fact_opportunity AS target
    USING #fact_opportunity_stg AS source
    ON target.opportunity_key = source.opportunity_key

    WHEN MATCHED THEN
        UPDATE SET
            target.opportunity_id = source.opportunity_id,
            target.customer_key = source.customer_key,
            target.opportunity_stage = source.opportunity_stage,
            target.estimated_value = source.estimated_value,
            target.close_date_key = source.close_date_key,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            opportunity_key,
            opportunity_id,
            customer_key,
            opportunity_stage,
            estimated_value,
            close_date_key,
            modified_date
        )
        VALUES (
            source.opportunity_key,
            source.opportunity_id,
            source.customer_key,
            source.opportunity_stage,
            source.estimated_value,
            source.close_date_key,
            source.modified_date
        );


    SELECT @rows_changed = @@ROWCOUNT;

   
    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #fact_opportunity_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_opportunity' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'fact_opportunity' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_opportunity', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #fact_opportunity_stg;

END;
GO

-- EXEC dbo.sp_iload_fact_opportunity