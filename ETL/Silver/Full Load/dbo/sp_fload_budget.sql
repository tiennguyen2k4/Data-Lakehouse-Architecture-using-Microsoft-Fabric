USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_budget AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.dbo.[budget]

    INSERT INTO DATN_Silver_WH.dbo.[budget] (
        account_id,
        department_id,
        budget_date,
        budget,
        row_hash,
        modified_date
    )
    SELECT
        account_id,
        department_id,
        [date] AS budget_date,
        budget,
    
        LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5',
            CONCAT(
                ISNULL(CAST(account_id AS VARCHAR), ''),
                '|',
                ISNULL(CAST(department_id AS VARCHAR), ''),
                '|',
                ISNULL(CONVERT(VARCHAR, [date], 120), ''),
                '|',
                ISNULL(CAST(budget AS VARCHAR), '')
            )
        ), 2)) AS row_hash,
       
        GETDATE() AS modified_date
    FROM DATN_Bronze_LH.dbo.[m_budget]
    ORDER BY account_id;


    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.dbo.[budget]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.dbo.[budget]


    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'budget' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'budget' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('budget', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END;
GO

-- EXEC dbo.sp_fload_budget