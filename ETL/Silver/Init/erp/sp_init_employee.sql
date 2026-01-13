USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_employee AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.employee

CREATE TABLE DATN_Silver_WH.erp.employee (
    employee_id INT NOT NULL,
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

-- EXEC erp.sp_init_employee