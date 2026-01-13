USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_fact_sales
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
    WHERE table_name = 'fact_sales' AND layer_type = 'gold';


    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';

 

    IF OBJECT_ID('tempdb..#fact_sales_stg') IS NOT NULL
        DROP TABLE #fact_sales_stg;

    SELECT
        sod.sales_order_id AS sales_order_key,  
        c.customer_key,
        p.product_key,
        e.employee_key,
        st.sales_territory_key,
        sod.sales_order_number,
        sod.sales_order_detail_id,
        d.date_key,
        sod.order_quantity,
        sod.unit_price,
        sod.unit_cost,
        sod.discount_percentage,
        sod.sales_amount,
        sod.total_product_cost,
        sod.gross_margin,
        sod.discount_amount,
        sod.modified_date
    INTO #fact_sales_stg
    FROM DATN_Silver_WH.erp.sales sod
    LEFT JOIN DATN_Gold_WH.dbo.dim_customer c
        ON c.customer_key = sod.customer_id  
    LEFT JOIN DATN_Gold_WH.dbo.dim_product p
        ON p.product_key = sod.product_id  
    LEFT JOIN DATN_Gold_WH.dbo.dim_employee e
        ON e.employee_key = sod.employee_id  
    LEFT JOIN DATN_Gold_WH.dbo.dim_sales_territory st
        ON st.sales_territory_key = sod.sales_territory_id  
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d
        ON d.[date] = sod.order_date
   
    WHERE sod.modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.fact_sales AS target
    USING #fact_sales_stg AS source
    ON target.sales_order_key = source.sales_order_key
       AND target.sales_order_detail_id = source.sales_order_detail_id

    WHEN MATCHED THEN
        UPDATE SET
            target.customer_key = source.customer_key,
            target.product_key = source.product_key,
            target.employee_key = source.employee_key,
            target.sales_territory_key = source.sales_territory_key,
            target.sales_order_number = source.sales_order_number,
            target.order_date_key = source.date_key,
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
            sales_order_key, customer_key, product_key, employee_key,
            sales_territory_key, sales_order_number, sales_order_detail_id,
            order_date_key, order_quantity, unit_price, unit_cost,
            discount_percentage, sales_amount, total_product_cost,
            gross_margin, discount_amount, modified_date
        )
        VALUES (
            source.sales_order_key, source.customer_key, source.product_key,
            source.employee_key, source.sales_territory_key, source.sales_order_number,
            source.sales_order_detail_id, source.date_key, source.order_quantity,
            source.unit_price, source.unit_cost, source.discount_percentage,
            source.sales_amount, source.total_product_cost, source.gross_margin,
            source.discount_amount, source.modified_date
        );


    SELECT @rows_changed = @@ROWCOUNT;


    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #fact_sales_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_sales' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'fact_sales' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_sales', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #fact_sales_stg;

END;
GO

-- EXEC dbo.sp_iload_fact_sale