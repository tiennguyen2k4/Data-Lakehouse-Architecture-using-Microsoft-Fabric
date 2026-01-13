USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_sales AS
BEGIN
    SET NOCOUNT ON;

    -- Full load
    TRUNCATE TABLE DATN_Silver_WH.erp.sales

    INSERT INTO DATN_Silver_WH.erp.sales
    SELECT
        soh.SalesOrderID AS sales_order_id,
        soh.CustomerID AS customer_id,
        sod.ProductID AS product_id,
        ISNULL(soh.SalesPersonID, -1) AS employee_id,
        ISNULL(soh.TerritoryID, -1) AS sales_territory_id,
        soh.SalesOrderNumber AS sales_order_number,
        sod.SalesOrderDetailID AS sales_order_detail_id,
        CAST(soh.OrderDate AS DATETIME2(0)) AS order_date,
        sod.OrderQty AS order_quantity,
        sod.UnitPrice AS unit_price,
        ISNULL(p.StandardCost, 0) AS unit_cost,
        sod.UnitPriceDiscount AS discount_percentage,
        sod.LineTotal AS sales_amount,
        (sod.OrderQty * ISNULL(CAST(p.StandardCost AS DECIMAL(18,2)), 0)) AS total_product_cost,
        (sod.LineTotal - (sod.OrderQty * ISNULL(CAST(p.StandardCost AS DECIMAL(18,2)), 0))) AS gross_margin,
        (sod.OrderQty * sod.UnitPrice * sod.UnitPriceDiscount) AS discount_amount,
        -- LẤY MAX của cả Header và Detail ModifiedDate
        CASE
            WHEN CAST(soh.ModifiedDate AS DATETIME2(0)) > CAST(sod.ModifiedDate AS DATETIME2(0))
            THEN CAST(soh.ModifiedDate AS DATETIME2(0))
            ELSE CAST(sod.ModifiedDate AS DATETIME2(0))
        END AS modified_date
    FROM DATN_Bronze_LH.dbo.sales_order_header soh
    LEFT JOIN DATN_Bronze_LH.dbo.sales_order_detail sod
        ON soh.SalesOrderID = sod.SalesOrderID
    LEFT JOIN DATN_Bronze_LH.dbo.product p
        ON sod.ProductID = p.ProductID
    WHERE soh.Status = 5
    ORDER BY sales_order_id

    -- Cập nhật watermark cho Silver
    DECLARE @max_modified DATETIME2(0)
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.sales

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.sales

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'sales' AND layer_type = 'silver')
    BEGIN
        UPDATE DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'sales' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('sales', @max_modified, 'silver', GETDATE(), @row_count)
    END

END
GO

-- EXEC erp.sp_fload_sales


