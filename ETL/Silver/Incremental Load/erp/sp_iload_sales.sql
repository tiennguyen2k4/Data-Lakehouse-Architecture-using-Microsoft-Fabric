USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_sales AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @watermark_date DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

    SELECT @watermark_date = ISNULL(CAST(max_modified_date AS DATETIME2(0)), '1900-01-01 00:00:00')
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'sales' AND layer_type = 'silver';


    IF OBJECT_ID('tempdb..#sales_stg') IS NOT NULL DROP TABLE #sales_stg;

    SELECT
        
        TRY_CAST(soh.SalesOrderID AS BIGINT) AS sales_order_id,
        TRY_CAST(sod.SalesOrderDetailID AS BIGINT) AS sales_order_detail_id,
        TRY_CAST(soh.CustomerID AS INT) AS customer_id,
        TRY_CAST(sod.ProductID AS INT) AS product_id,
        ISNULL(TRY_CAST(soh.SalesPersonID AS INT), -1) AS employee_id,
        ISNULL(TRY_CAST(soh.TerritoryID AS INT), -1) AS sales_territory_id,

        soh.SalesOrderNumber AS sales_order_number,
        CAST(soh.OrderDate AS DATE) AS order_date,

        TRY_CAST(sod.OrderQty AS INT) AS order_quantity,
        TRY_CAST(sod.UnitPrice AS DECIMAL(19,4)) AS unit_price,
        ISNULL(TRY_CAST(p.StandardCost AS DECIMAL(19,4)), 0) AS unit_cost,
        TRY_CAST(sod.UnitPriceDiscount AS DECIMAL(19,4)) AS discount_percentage,
        TRY_CAST(sod.LineTotal AS DECIMAL(19,4)) AS sales_amount,

        -- Calculations
        (TRY_CAST(sod.OrderQty AS INT) * ISNULL(TRY_CAST(p.StandardCost AS DECIMAL(19,4)), 0)) AS total_product_cost,
        (TRY_CAST(sod.LineTotal AS DECIMAL(19,4)) - (TRY_CAST(sod.OrderQty AS INT) * ISNULL(TRY_CAST(p.StandardCost AS DECIMAL(19,4)), 0))) AS gross_margin,
        (TRY_CAST(sod.OrderQty AS INT) * TRY_CAST(sod.UnitPrice AS DECIMAL(19,4)) * TRY_CAST(sod.UnitPriceDiscount AS DECIMAL(19,4))) AS discount_amount,

        -- Modified date
        CAST(
            CASE
                WHEN soh.ModifiedDate > sod.ModifiedDate
                THEN soh.ModifiedDate
                ELSE sod.ModifiedDate
            END AS DATETIME2(0)
        ) AS modified_date,
        @CurrentLoadTime AS inserted_load_date
    INTO #sales_stg
    FROM DATN_Bronze_LH.dbo.sales_order_header soh
    LEFT JOIN DATN_Bronze_LH.dbo.sales_order_detail sod
        ON TRY_CAST(soh.SalesOrderID AS BIGINT) = TRY_CAST(sod.SalesOrderID AS BIGINT)
    LEFT JOIN DATN_Bronze_LH.dbo.product p
        ON TRY_CAST(sod.ProductID AS INT) = TRY_CAST(p.ProductID AS INT)

    WHERE soh.Status = 5
      AND (soh.ModifiedDate > @watermark_date
           OR sod.ModifiedDate > @watermark_date)
      
      AND TRY_CAST(soh.SalesOrderID AS BIGINT) IS NOT NULL
      AND TRY_CAST(sod.SalesOrderDetailID AS BIGINT) IS NOT NULL;


    MERGE INTO DATN_Silver_WH.erp.sales AS target
    USING #sales_stg AS source
    ON target.sales_order_detail_id = source.sales_order_detail_id

    WHEN MATCHED AND target.modified_date <> source.modified_date THEN
        UPDATE SET
            target.customer_id = source.customer_id,
            target.product_id = source.product_id,
            target.employee_id = source.employee_id,
            target.sales_territory_id = source.sales_territory_id,
            target.sales_order_number = source.sales_order_number,
            target.order_date = source.order_date,
            target.order_quantity = source.order_quantity,
            target.unit_price = source.unit_price,
            target.unit_cost = source.unit_cost,
            target.discount_percentage = source.discount_percentage,
            target.sales_amount = source.sales_amount,
            target.total_product_cost = source.total_product_cost,
            target.gross_margin = source.gross_margin,
            target.discount_amount = source.discount_amount,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            sales_order_id, customer_id, product_id, employee_id,
            sales_territory_id, sales_order_number, sales_order_detail_id,
            order_date, order_quantity, unit_price, unit_cost,
            discount_percentage, sales_amount, total_product_cost,
            gross_margin, discount_amount, modified_date
        )
        VALUES (
            source.sales_order_id, source.customer_id, source.product_id,
            source.employee_id, source.sales_territory_id, source.sales_order_number,
            source.sales_order_detail_id, source.order_date, source.order_quantity,
            source.unit_price, source.unit_cost, source.discount_percentage,
            source.sales_amount, source.total_product_cost, source.gross_margin,
            source.discount_amount, source.modified_date
        );

    SELECT @rows_changed = @@ROWCOUNT;


    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #sales_stg;

    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @watermark_date;

    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'sales' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'sales' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('sales', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    DROP TABLE #sales_stg;
END
GO