USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_account AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_account

CREATE TABLE DATN_Gold_WH.dbo.dim_account (
    account_key INT NOT NULL,
	parent_id INT,
	account_code INT NOT NULL,
	parent_account_code INT,
	account_description VARCHAR(255),
	account_type VARCHAR(50),
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_account