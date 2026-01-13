USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_fact_transaction
    @etl_date DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);


    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'fact_transaction' AND layer_type = 'gold';


    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';


    IF OBJECT_ID('tempdb..#fact_transaction_stg') IS NOT NULL
        DROP TABLE #fact_transaction_stg;

    SELECT
        t.transaction_id AS transaction_key,  
        t.transaction_code,
        t.transaction_line_id,
        a.account_key,
        dep.department_key,
        c.class_key,
        t.transaction_type,
        t.entry_type,
        t.description,
        dt.date_key,
        t.debit_amount,
        t.credit_amount,
        t.amount,
        t.modified_date
    INTO #fact_transaction_stg
    FROM DATN_Silver_WH.erp.[transaction] t
    LEFT JOIN DATN_Gold_WH.dbo.dim_account a
        ON a.account_key = t.account_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_department dep
        ON dep.department_key = t.department_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_class c
        ON c.class_key = t.class_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_date dt
        ON dt.[date] = t.transaction_date
    WHERE t.modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.fact_transaction AS target
    USING #fact_transaction_stg AS source
    ON target.transaction_key = source.transaction_key
       AND target.transaction_line_id = source.transaction_line_id

    WHEN MATCHED THEN
        UPDATE SET
            target.transaction_code = source.transaction_code,
            target.account_key = source.account_key,
            target.department_key = source.department_key,
            target.class_key = source.class_key,
            target.transaction_type = source.transaction_type,
            target.entry_type = source.entry_type,
            target.description = source.description,
            target.transaction_date_key = source.date_key,
            target.debit_amount = source.debit_amount,
            target.credit_amount = source.credit_amount,
            target.amount = source.amount,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            transaction_key,
            transaction_code,
            transaction_line_id,
            account_key,
            department_key,
            class_key,
            transaction_type,
            entry_type,
            description,
            transaction_date_key,
            debit_amount,
            credit_amount,
            amount,
            modified_date
        )
        VALUES (
            source.transaction_key,
            source.transaction_code,
            source.transaction_line_id,
            source.account_key,
            source.department_key,
            source.class_key,
            source.transaction_type,
            source.entry_type,
            source.description,
            source.date_key,
            source.debit_amount,
            source.credit_amount,
            source.amount,
            source.modified_date
        );

    SELECT @rows_changed = @@ROWCOUNT;

  
    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #fact_transaction_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_transaction' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'fact_transaction' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_transaction', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END

    DROP TABLE #fact_transaction_stg;

END;
GO

-- EXEC dbo.sp_iload_fact_transaction