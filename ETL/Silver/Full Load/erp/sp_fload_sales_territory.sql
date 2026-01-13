USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_sales_territory AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.erp.sales_territory

    INSERT INTO DATN_Silver_WH.erp.sales_territory
    SELECT TerritoryID AS sales_territory_id, [Group] AS sales_territory_group, Name AS sales_territory_country, CAST(ModifiedDate AS DATETIME2(0)) AS modified_date
    FROM DATN_Bronze_LH.dbo.sales_territory
    ORDER BY sales_territory_id;

     -- Cập nhật watermark cho Silver layer
    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.[sales_territory]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.[sales_territory]

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'sales_territory' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'sales_territory' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('sales_territory', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END;
GO

-- EXEC erp.sp_fload_sales_territory