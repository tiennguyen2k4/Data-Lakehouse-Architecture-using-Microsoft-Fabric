USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_employee AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_employee

CREATE TABLE DATN_Gold_WH.dbo.dim_employee (
    employee_key INT NOT NULL,
    employee_national_number VARCHAR(25),
	name VARCHAR(255),
    position VARCHAR(255),
    birth_day DATE,
    gender VARCHAR(1),
	email VARCHAR(255),
    phone VARCHAR(100),
    address VARCHAR(255),
    start_date DATE,
    end_date DATE,
    is_valid INT,
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_employee