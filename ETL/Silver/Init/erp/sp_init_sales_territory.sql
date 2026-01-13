USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_sales_territory AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.sales_territory

CREATE TABLE DATN_Silver_WH.erp.sales_territory (
    sales_territory_id INT NOT NULL,
	sales_territory_group VARCHAR(50),
	sales_territory_country VARCHAR(50),
	modified_date DATETIME2(0)
)
GO

-- EXEC erp.sp_init_sales_territory