USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_fact_budget AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.[fact_budget]

CREATE TABLE DATN_Gold_WH.dbo.[fact_budget] (
    account_key INT,
	department_key INT,
    budget_date_key INT,
    budget DECIMAL(18,2),
    modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_fact_budget