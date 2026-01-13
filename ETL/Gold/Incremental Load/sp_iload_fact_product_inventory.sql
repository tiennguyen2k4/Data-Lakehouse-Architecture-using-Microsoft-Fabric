USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_fact_product_inventory
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
    WHERE table_name = 'fact_product_inventory' AND layer_type = 'gold';

   
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';

 

    IF OBJECT_ID('tempdb..#fact_product_inventory_stg') IS NOT NULL
        DROP TABLE #fact_product_inventory_stg;

    SELECT
        p.product_key,
        l.location_key,
        d.date_key,
        da.unit_in,
        da.unit_out,
        da.unit_cost,
        da.unit_balance,
        da.modified_date
    INTO #fact_product_inventory_stg
    FROM DATN_Silver_WH.erp.product_inventory da  
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d
        ON d.[date] = da.transaction_date
    LEFT JOIN DATN_Gold_WH.dbo.dim_location l
        ON l.location_key = da.location_id  
    LEFT JOIN DATN_Gold_WH.dbo.dim_product p
        ON p.product_key = da.product_id  
    WHERE da.modified_date > @MaxModifiedDate;


    MERGE INTO DATN_Gold_WH.dbo.fact_product_inventory AS target
    USING #fact_product_inventory_stg AS source
    ON target.product_key = source.product_key
       AND target.location_key = source.location_key
       AND target.date_key = source.date_key  

    WHEN MATCHED THEN
        UPDATE SET
            target.unit_in = source.unit_in,
            target.unit_out = source.unit_out,
            target.unit_cost = source.unit_cost,
            target.unit_balance = source.unit_balance,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            product_key,
            location_key,
            date_key,
            unit_in,
            unit_out,
            unit_cost,
            unit_balance,
            modified_date
        )
        VALUES (
            source.product_key,
            source.location_key,
            source.date_key,
            source.unit_in,
            source.unit_out,
            source.unit_cost,
            source.unit_balance,
            source.modified_date
        );


    SELECT @rows_changed = @@ROWCOUNT;




    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #fact_product_inventory_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_product_inventory' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'fact_product_inventory' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_product_inventory', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #fact_product_inventory_stg;

END;
GO

-- EXEC dbo.sp_iload_fact_product_inventory