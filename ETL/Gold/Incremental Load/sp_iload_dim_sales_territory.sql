USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_sales_territory AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);



    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_sales_territory' AND layer_type = 'gold';

 
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';


    IF OBJECT_ID('tempdb..#dim_sales_territory_stg') IS NOT NULL
        DROP TABLE #dim_sales_territory_stg;

    SELECT
        sales_territory_id,
        sales_territory_group,
        sales_territory_country,
        modified_date
    INTO #dim_sales_territory_stg
    FROM DATN_Silver_WH.erp.sales_territory

    WHERE modified_date > @MaxModifiedDate;

   

    MERGE INTO DATN_Gold_WH.dbo.dim_sales_territory AS target
    USING #dim_sales_territory_stg AS source
    ON target.sales_territory_key = source.sales_territory_id

    WHEN MATCHED THEN
        UPDATE SET
            target.sales_territory_group = source.sales_territory_group,
            target.sales_territory_country = source.sales_territory_country,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            sales_territory_key,
            sales_territory_group,
            sales_territory_country,
            modified_date
        )
        VALUES (
            source.sales_territory_id,
            source.sales_territory_group,
            source.sales_territory_country,
            source.modified_date
        );


    SELECT @rows_changed = @@ROWCOUNT;


    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #dim_sales_territory_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_sales_territory' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_sales_territory' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_sales_territory', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END

  
    DROP TABLE #dim_sales_territory_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_sales_territory