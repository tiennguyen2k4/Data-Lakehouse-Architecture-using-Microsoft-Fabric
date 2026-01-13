USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_fact_sales AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE DATN_Gold_WH.dbo.fact_sales;

    INSERT INTO DATN_Gold_WH.dbo.fact_sales
    SELECT
        sod.sales_order_id,
        c.customer_key,
        p.product_key,
        e.employee_key,
        st.sales_territory_key,
        sod.sales_order_number,
        sod.sales_order_detail_id,
        d.date_key,
        sod.order_quantity,
        sod.unit_price,
        unit_cost,
        sod.discount_percentage,
        sod.sales_amount,
        sod.total_product_cost,
        sod.gross_margin,
        sod.discount_amount,
        sod.modified_date
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
    ORDER BY sales_order_id


    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[fact_sales]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[fact_sales]


    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_sales' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'fact_sales' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_sales', @max_modified, 'gold',  GETDATE(), @row_count)
    END

END
GO

-- EXEC erp.sp_fload_sales
