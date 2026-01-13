USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_budget AS

DROP TABLE IF EXISTS DATN_Silver_WH.dbo.[budget]

CREATE TABLE DATN_Silver_WH.dbo.[budget] (
    account_id INT,
	department_id INT,
    budget_date DATETIME2(0),
    budget DECIMAL(18,2),
    row_hash VARCHAR(64),
    modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_budget