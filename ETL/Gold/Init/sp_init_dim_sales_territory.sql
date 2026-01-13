USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_sales_territory AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_sales_territory

CREATE TABLE DATN_Gold_WH.dbo.dim_sales_territory (
    sales_territory_key INT NOT NULL,
	sales_territory_group VARCHAR(50),
	sales_territory_country VARCHAR(50),
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_sales_territory