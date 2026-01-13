USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_account AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

 

    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_account' AND layer_type = 'gold';


    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';

 

    IF OBJECT_ID('tempdb..#dim_account_stg') IS NOT NULL
        DROP TABLE #dim_account_stg;

    SELECT
        account_id,
        parent_id,
        account_code,
        parent_account_code,
        account_description,
        account_type,
        modified_date
    INTO #dim_account_stg
    FROM DATN_Silver_WH.erp.account

    WHERE modified_date > @MaxModifiedDate;

   

    MERGE INTO DATN_Gold_WH.dbo.dim_account AS target
    USING #dim_account_stg AS source
    ON target.account_key = source.account_id

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
            account_key,
            parent_id,
            account_code,
            parent_account_code,
            account_description,
            account_type,
            modified_date
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
    FROM #dim_account_stg;

    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

 
    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_account' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_account' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_account', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #dim_account_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_account