USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_transaction AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.[transaction]

CREATE TABLE DATN_Silver_WH.erp.[transaction] (
    transaction_id INT NOT NULL,
    transaction_code VARCHAR(25),
    transaction_line_id INT,
    account_id INT,
	department_id INT,
    class_id INT,
    transaction_type VARCHAR(50),
    entry_type VARCHAR(25),
    description VARCHAR(500),
    transaction_date DATETIME2(0),
    debit_amount DECIMAL(18,2),
    credit_amount DECIMAL(18,2),
    amount DECIMAL(18,2),
    modified_date DATETIME2(0)
)
GO

-- EXEC erp.sp_init_transaction