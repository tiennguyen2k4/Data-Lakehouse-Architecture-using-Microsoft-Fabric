USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_customer AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_customer

CREATE TABLE DATN_Gold_WH.dbo.dim_customer (
    customer_key INT NOT NULL,
    customer_erp_id INT,
    customer_crm_id VARCHAR(10),
	name VARCHAR(255),
	email VARCHAR(255),
    phone VARCHAR(100),
    address VARCHAR(255),
    birth_day DATE,
    gender VARCHAR(1),
    is_lead INT,
    is_person INT,
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_customer