USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_location AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.location

CREATE TABLE DATN_Silver_WH.erp.location (
    location_id INT NOT NULL,
	name VARCHAR(255),
	cost_rate DECIMAL(18,2),
	availability DECIMAL(18,2),
	modified_date DATETIME2(0)
)
GO

-- EXEC erp.sp_init_location