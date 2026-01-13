USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_fact_product_inventory
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE DATN_Gold_WH.dbo.fact_product_inventory;

    INSERT INTO DATN_Gold_WH.dbo.fact_product_inventory
    SELECT
        p.product_key,
        l.location_key,
        d.date_key,
        da.unit_in,
        da.unit_out,
        da.unit_cost,
        da.unit_balance,
        da.modified_date
    FROM DATN_Silver_WH.erp.product_inventory da
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d ON d.[date]=da.transaction_date
    LEFT JOIN DATN_Gold_WH.dbo.dim_location l ON l.location_key=da.location_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_product p ON p.product_key=da.product_id;


    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[fact_product_inventory]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[fact_product_inventory]


    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_product_inventory' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'fact_product_inventory' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_product_inventory', @max_modified, 'gold',  GETDATE(), @row_count)
    END
END
GO