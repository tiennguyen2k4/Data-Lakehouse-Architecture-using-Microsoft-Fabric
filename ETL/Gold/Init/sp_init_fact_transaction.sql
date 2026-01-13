USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_fact_transaction AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.[fact_transaction]

CREATE TABLE DATN_Gold_WH.dbo.[fact_transaction] (
    transaction_key INT NOT NULL,
    transaction_code VARCHAR(25),
    transaction_line_id INT,
    account_key INT,
	department_key INT,
    class_key INT,
    transaction_type VARCHAR(50),
    entry_type VARCHAR(25),
    description VARCHAR(500),
    transaction_date_key INT,
    debit_amount DECIMAL(18,2),
    credit_amount DECIMAL(18,2),
    amount DECIMAL(18,2),
    modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_fact_transaction