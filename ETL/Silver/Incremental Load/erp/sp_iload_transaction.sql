USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_transaction
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @watermark_date DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

 

    SELECT @watermark_date = ISNULL(CAST(max_modified_date AS DATETIME2(0)), '1900-01-01 00:00:00')
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'transaction' AND layer_type = 'silver';



    IF OBJECT_ID('tempdb..#transaction_stg') IS NOT NULL DROP TABLE #transaction_stg;

    SELECT
        transaction_id,
        transaction_code,
        transaction_line_id,
        account_id,
        department_id,
        class_id,
        transaction_type,
        entry_type,
        description,
        transaction_date,
        debit_amount,
        credit_amount,
        amount,
        CAST(ModifiedDate AS DATETIME2(0)) AS modified_date,
        @CurrentLoadTime AS inserted_load_date
    INTO #transaction_stg
 
    FROM DATN_Bronze_LH.dbo.[transaction]
  
    WHERE CAST(ModifiedDate AS DATETIME2(0)) > @watermark_date;



    MERGE INTO DATN_Silver_WH.erp.[transaction] AS target
    USING #transaction_stg AS source
    ON target.transaction_id = source.transaction_id
        AND target.transaction_line_id = source.transaction_line_id

    WHEN MATCHED AND target.modified_date <> source.modified_date
        THEN UPDATE SET
            target.account_id = source.account_id,
            target.department_id = source.department_id,
            target.class_id = source.class_id,
            target.transaction_type = source.transaction_type,
            target.entry_type = source.entry_type,
            target.description = source.description,
            target.transaction_date = source.transaction_date,
            target.debit_amount = source.debit_amount,
            target.credit_amount = source.credit_amount,
            target.amount = source.amount,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            transaction_id, transaction_code, transaction_line_id,
            account_id, department_id, class_id, transaction_type,
            entry_type, description, transaction_date, debit_amount,
            credit_amount, amount, modified_date
        )
        VALUES (
            source.transaction_id, source.transaction_code, source.transaction_line_id,
            source.account_id, source.department_id, source.class_id, source.transaction_type,
            source.entry_type, source.description, source.transaction_date, source.debit_amount,
            source.credit_amount, source.amount, source.modified_date
        );


    SELECT @rows_changed = @@ROWCOUNT;

  
    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #transaction_stg;

    
    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @watermark_date;


    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'transaction' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'transaction' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('transaction', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    -- Dọn dẹp bảng tạm
    DROP TABLE #transaction_stg;

END;
GO