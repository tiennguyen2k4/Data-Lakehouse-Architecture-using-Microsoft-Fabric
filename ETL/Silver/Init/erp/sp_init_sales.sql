USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_sales AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.sales

CREATE TABLE DATN_Silver_WH.erp.sales (
    sales_order_id INT,
    customer_id INT,
	product_id INT,
    employee_id INT,
    sales_territory_id INT,
    sales_order_number VARCHAR(25),
    sales_order_detail_id INT,
    order_date DATETIME2(0),
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

-- EXEC erp.sp_init_sales