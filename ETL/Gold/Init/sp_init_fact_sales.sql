USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_fact_sales AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.fact_sales

CREATE TABLE DATN_Gold_WH.dbo.fact_sales (
    sales_order_key INT,
    customer_key INT,
	product_key INT,
    employee_key INT,
    sales_territory_key INT,
    sales_order_number VARCHAR(25),
    sales_order_detail_id INT,
    order_date_key INT,
    order_quantity INT,
    unit_price DECIMAL(18,2),
    unit_cost DECIMAL(18,2),
    discount_percentage DECIMAL(18,2),
    sales_amount DECIMAL(18,2),
    total_product_cost DECIMAL(18,2),
    gross_margin DECIMAL(18,2),
    discount_amount DECIMAL(18,2),
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_fact_sales