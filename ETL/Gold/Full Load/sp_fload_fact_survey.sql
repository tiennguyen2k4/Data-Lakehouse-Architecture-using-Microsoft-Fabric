USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_fact_survey AS

BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE DATN_Gold_WH.dbo.fact_survey;

    INSERT INTO DATN_Gold_WH.dbo.fact_survey
    SELECT
        s.survey_id,
        s.survey_code,
        c.customer_key,
        p.product_key,
        d.date_key,
        s.overall_rating,
        s.quality_rating,
        s.price_rating,
        s.service_rating,
        s.recommendation,
        s.purchase_channel,
        s.customers_segment,
        s.comments,
        s.modified_date
    FROM DATN_Silver_WH.dbo.survey s
    LEFT JOIN DATN_Gold_WH.dbo.dim_customer c ON c.customer_key=s.customer_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_product p ON p.product_key=s.product_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d ON d.[date]=s.survey_date
    ORDER BY s.survey_id;


    DECLARE @max_modified DATETIME2(0)
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[fact_survey]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[fact_survey]

 
    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_survey' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'fact_survey' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_survey', @max_modified, 'gold',  GETDATE(), @row_count)
    END
END
GO

-- EXEC dbo.sp_fload_fact_survey