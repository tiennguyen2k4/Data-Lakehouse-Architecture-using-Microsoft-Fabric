USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_account AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.account

CREATE TABLE DATN_Silver_WH.erp.account (
    account_id INT NOT NULL,
	parent_id INT,
	account_code INT NOT NULL,
	parent_account_code INT,
	account_description VARCHAR(255),
	account_type VARCHAR(50),
	modified_date DATETIME2(0)
)
GO

-- EXEC erp.sp_init_account