USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_department AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_department

CREATE TABLE DATN_Gold_WH.dbo.dim_department (
    department_key INT NOT NULL,
	department_code VARCHAR(10),
	name VARCHAR(255),
	group_name VARCHAR(255),
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_department