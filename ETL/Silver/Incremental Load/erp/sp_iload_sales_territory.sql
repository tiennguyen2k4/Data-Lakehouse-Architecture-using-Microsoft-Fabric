USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_sales_territory AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE(); 
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

 
    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'sales_territory' AND layer_type = 'silver';

    -- Nếu chưa có Watermark, đặt giá trị mặc định rất cũ
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';

    

    IF OBJECT_ID('tempdb..#territory_stg') IS NOT NULL DROP TABLE #territory_stg;

    SELECT
        TerritoryID AS sales_territory_id,
        [Group] AS sales_territory_group,
        Name AS sales_territory_country,
        CAST(ModifiedDate AS DATETIME2(0)) AS modified_date,
        @CurrentLoadTime AS inserted_load_date 
    INTO #territory_stg
    FROM DATN_Bronze_LH.dbo.sales_territory
    WHERE CAST(ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;

   
    MERGE INTO DATN_Silver_WH.erp.sales_territory AS target
    USING #territory_stg AS source
    ON target.sales_territory_id = source.sales_territory_id

    WHEN MATCHED THEN
        UPDATE SET
            target.sales_territory_group = source.sales_territory_group,
            target.sales_territory_country = source.sales_territory_country,
            target.modified_date = source.modified_date
           

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            sales_territory_id, sales_territory_group, sales_territory_country,
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
    FROM #territory_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    -- Update hoặc Insert Watermark
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'sales_territory' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'sales_territory' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('sales_territory', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

 
    DROP TABLE #territory_stg;
END
GO