USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_fact_transaction AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE DATN_Gold_WH.dbo.[fact_transaction];

    INSERT INTO DATN_Gold_WH.dbo.[fact_transaction]
    SELECT t.transaction_id, t.transaction_code, t.transaction_line_id, a.account_key,
        dp.department_key, c.class_key,
        t.transaction_type, t.entry_type, t.description, d.date_key,
        t.debit_amount, t.credit_amount,
        t.amount, t.modified_date
    FROM DATN_Silver_WH.erp.[transaction] t
    LEFT JOIN DATN_Gold_WH.dbo.dim_account a ON a.account_key=t.account_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_department dp ON dp.department_key=t.department_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_class c ON c.class_key=t.class_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d ON d.[date]=t.transaction_date
    ORDER BY transaction_id;


    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[fact_transaction]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[fact_transaction]


    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_transaction' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'fact_transaction' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_transaction', @max_modified, 'gold',  GETDATE(), @row_count)
    END
END
GO

-- EXEC dbo.sp_fload_fact_transaction

