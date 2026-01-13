USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_fact_opportunity AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Gold_WH.dbo.fact_opportunity;

    INSERT INTO DATN_Gold_WH.dbo.fact_opportunity (
        opportunity_key,
        opportunity_id,
        customer_key,
        opportunity_stage,
        estimated_value,
        close_date_key,
        modified_date
    )
    SELECT
        o.opportunity_key,
        o.opportunity_id,
        o.customer_id,
        o.opportunity_stage,
        o.estimated_value,
        d.date_key,
        o.modified_date
    FROM DATN_Silver_WH.crm.opportunity o
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d ON d.[date]=o.close_date
    LEFT JOIN DATN_Gold_WH.dbo.dim_customer c ON c.customer_key=o.customer_id
    ORDER BY o.opportunity_key


    DECLARE @max_modified DATETIME2(0)
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[fact_opportunity]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[fact_opportunity]


    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_opportunity' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'fact_opportunity' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_opportunity', @max_modified, 'gold',  GETDATE(), @row_count)
    END

END;
GO
-- EXEC dbo.sp_fload_fact_opportunity