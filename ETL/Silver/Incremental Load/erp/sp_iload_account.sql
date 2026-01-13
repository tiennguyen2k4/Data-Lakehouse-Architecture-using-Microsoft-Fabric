USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_account AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0); 



    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'account' AND layer_type = 'silver';

    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#acc_stg') IS NOT NULL DROP TABLE #acc_stg;

    SELECT
        account_id,
        parent_id,
        account_code,
        parent_account_code,
        account_description,
        account_type,
        CAST(ModifiedDate AS DATETIME2(0)) AS modified_date
    INTO #acc_stg
    FROM DATN_Bronze_LH.dbo.account
    WHERE CAST(ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;

 

    MERGE INTO DATN_Silver_WH.erp.account AS target
    USING #acc_stg AS source
    ON target.account_id = source.account_id

    WHEN MATCHED THEN
        UPDATE SET
            target.parent_id = source.parent_id,
            target.account_code = source.account_code,
            target.parent_account_code = source.parent_account_code,
            target.account_description = source.account_description,
            target.account_type = source.account_type,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            account_id, parent_id, account_code, parent_account_code,
            account_description, account_type, modified_date
        )
        VALUES (
            source.account_id,
            source.parent_id,
            source.account_code,
            source.parent_account_code,
            source.account_description,
            source.account_type,
            source.modified_date
        );


    SELECT @rows_changed = @@ROWCOUNT;

    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #acc_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    -- Update hoặc Insert Watermark
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'account' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'account' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('account', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    DROP TABLE #acc_stg;
END
GO