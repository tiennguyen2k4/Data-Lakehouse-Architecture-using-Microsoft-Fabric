USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE crm.sp_fload_opportunity AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.crm.opportunity;

    INSERT INTO DATN_Silver_WH.crm.opportunity (
        opportunity_key,
        opportunity_id,
        customer_id,
        opportunity_stage,
        estimated_value,
        close_date,
        row_hash,
        modified_date
    )
    SELECT
        o.opportunity_key,
        o.opportunity_id,
        c.customer_id,
        o.opportunity_stage,
        o.estimated_value,
        o.close_date,
         -- Tính MD5 hash
            LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5',
                CONCAT(
                    ISNULL(CAST(o.opportunity_key AS VARCHAR), ''),
                    '|',
                    ISNULL(o.opportunity_id, ''),
                    '|',
                    ISNULL(CAST(c.customer_id AS VARCHAR), ''),
                    '|',
                    ISNULL(o.opportunity_stage, ''),
                    '|',
                    ISNULL(CAST(o.estimated_value AS VARCHAR), ''),
                    '|',
                    ISNULL(CONVERT(VARCHAR, o.close_date, 120), '')
                )
            ), 2)) AS row_hash,
        GETDATE() AS modified_date
    FROM DATN_Bronze_LH.dbo.opportunity o
    JOIN DATN_Silver_WH.erp.customer c ON c.customer_crm_id = o.lead_id
    ORDER BY o.opportunity_key;


    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.crm.[opportunity]

     DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.crm.[opportunity]


    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'opportunity' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'opportunity' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('opportunity', @max_modified, 'silver',  GETDATE(), @row_count)
    END

END;
GO
-- EXEC crm.sp_fload_opportunity