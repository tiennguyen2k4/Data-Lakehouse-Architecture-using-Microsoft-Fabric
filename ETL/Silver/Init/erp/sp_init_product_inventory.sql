USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_product_inventory AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.product_inventory

CREATE TABLE DATN_Silver_WH.erp.product_inventory (
    product_id INT NOT NULL,
    location_id VARCHAR(50),
    transaction_date DATETIME2(0),
    unit_in INT,
    unit_out INT,
    unit_cost DECIMAL(18,2),
    unit_balance INT,
    modified_date DATETIME2(0)
)
GO

-- EXEC erp.sp_init_product_inventory