USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_location AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_location

CREATE TABLE DATN_Gold_WH.dbo.dim_location (
    location_key INT NOT NULL,
	name VARCHAR(255),
	cost_rate DECIMAL(18,2),
	availability DECIMAL(18,2),
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_location