USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_fact_product_inventory AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.fact_product_inventory

CREATE TABLE DATN_Gold_WH.dbo.fact_product_inventory (
    product_key INT NOT NULL,
    location_key INT,
    date_key INT,
    unit_in INT,
    unit_out INT,
    unit_cost DECIMAL(18,2),
    unit_balance INT,
    modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_fact_product_inventory