USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_dim_account AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Gold_WH.dbo.dim_account

    INSERT INTO DATN_Gold_WH.dbo.dim_account
    SELECT account_id, parent_id, account_code, parent_account_code,
        account_description, account_type, modified_date
    FROM DATN_Silver_WH.erp.account
    ORDER BY account_id;

    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[dim_account]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[dim_account]

    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_account' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'dim_account' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_account', @max_modified, 'gold',  GETDATE(), @row_count)
    END

END;
GO

-- EXEC dbo.sp_fload_dim_account