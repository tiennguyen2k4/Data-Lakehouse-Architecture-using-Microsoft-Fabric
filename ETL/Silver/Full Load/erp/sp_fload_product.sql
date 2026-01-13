USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_product AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.erp.product

    INSERT INTO DATN_Silver_WH.erp.product
    SELECT
        p.ProductID AS product_id,
        p.Name AS name,
        pc.Name AS category,
        ps.Name AS subcategory,
        p.ProductNumber AS model,
        p.ProductLine AS line,
        p.Class AS class,
        p.Style AS style,
        p.Color AS color,
        p.Size AS size,
        p.Weight AS weight,
        ISNULL(pd.Description, p.Name) AS description,
        p.StandardCost AS standard_cost,
        p.ListPrice AS list_price,
        p.MakeFlag AS make_flag,
        p.FinishedGoodsFlag AS finished_goods_flag,
        p.SafetyStockLevel AS safety_stock_level,
        p.ReorderPoint AS reorder_point,
        p.DaysToManufacture AS days_to_manufacture,
        CAST(p.SellStartDate AS DATETIME2(0)) AS sell_start_date,
        CAST(p.SellEndDate AS DATETIME2(0)) AS sell_end_date,
        CAST(p.ModifiedDate AS DATETIME2(0)) AS modified_date
    FROM DATN_Bronze_LH.dbo.product p
    LEFT JOIN DATN_Bronze_LH.dbo.product_sub_category ps
        ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    LEFT JOIN DATN_Bronze_LH.dbo.product_category pc
        ON ps.ProductCategoryID = pc.ProductCategoryID
    LEFT JOIN DATN_Bronze_LH.dbo.product_model pm
        ON p.ProductModelID = pm.ProductModelID
    LEFT JOIN DATN_Bronze_LH.dbo.product_model_description_culture pmpdc
        ON pm.ProductModelID = pmpdc.ProductModelID
        AND pmpdc.CultureID = 'en'
    LEFT JOIN DATN_Bronze_LH.dbo.product_description pd
        ON pmpdc.ProductDescriptionID = pd.ProductDescriptionID
    ORDER BY p.ProductID;

     -- Cập nhật watermark cho Silver layer
    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.[product]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.[product]

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'product' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'product' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('product', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END
GO

-- EXEC erp.sp_fload_product
