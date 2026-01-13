USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_transaction AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE DATN_Silver_WH.erp.[transaction];

    INSERT INTO DATN_Silver_WH.erp.[transaction]
    SELECT transaction_id, transaction_code, transaction_line_id, account_id,
        department_id, CAST(class_id AS INT),
        transaction_type, entry_type, description, transaction_date,
        CAST(debit_amount AS DECIMAL(18,2)) AS debit_amount, CAST (credit_amount AS DECIMAL(18,2)) AS credit_amount,
        CAST(amount AS DECIMAL(18,2)) AS amount, CAST(ModifiedDate AS DATETIME2(0)) AS modified_date
    FROM DATN_Bronze_LH.dbo.[transaction]
    ORDER BY transaction_id;

     -- Cập nhật watermark cho Silver layer
    DECLARE @max_modified DATETIME2(0)
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.[transaction]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.[transaction]

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'transaction' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'transaction' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('transaction', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END
GO

-- EXEC erp.sp_fload_transaction

