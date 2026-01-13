USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_department AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.department

CREATE TABLE DATN_Silver_WH.erp.department (
    department_id INT NOT NULL,
	department_code VARCHAR(10),
	name VARCHAR(255),
	group_name VARCHAR(255),
	modified_date DATETIME2(0)
)
GO

-- EXEC erp.sp_init_department