USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_account AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.erp.account

    INSERT INTO DATN_Silver_WH.erp.account
    SELECT account_id, parent_id, account_code, parent_account_code,
        account_description , account_type, CAST(ModifiedDate AS DATETIME2(0))
    FROM DATN_Bronze_LH.dbo.account
    ORDER BY account_id;

     -- Cập nhật watermark cho Silver layer
    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.[account]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.[account]

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'account' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'account' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('account', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END;
GO

-- EXEC erp.sp_fload_account