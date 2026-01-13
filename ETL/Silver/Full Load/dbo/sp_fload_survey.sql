USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_survey AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @current_date DATETIME2(0) = GETDATE();

    TRUNCATE TABLE DATN_Silver_WH.dbo.survey;

    INSERT INTO DATN_Silver_WH.dbo.survey (
        survey_id,
        survey_code,
        customer_id,
        product_id,
        survey_date,
        overall_rating,
        quality_rating,
        price_rating,
        service_rating,
        recommendation,
        purchase_channel,
        customers_segment,
        comments,
        row_hash,
        modified_date
    )
    SELECT
        id AS survey_id,
        survey_code,
        customer_id,
        product_id,
        survey_date,
        overall_rating,
        quality_rating,
        price_rating,
        service_rating,
        recommendation,
        purchase_channel,
        customer_segment AS customers_segment,
        comments,
        LOWER(CONVERT(VARCHAR(64), HASHBYTES('MD5',
            CONCAT(
                ISNULL(CAST(survey_code AS VARCHAR), ''),
                '|',
                ISNULL(CAST(customer_id AS VARCHAR), ''),
                '|',
                ISNULL(CAST(product_id AS VARCHAR), ''),
                '|',
                ISNULL(CONVERT(VARCHAR, survey_date, 120), ''),
                '|',
                ISNULL(CAST(overall_rating AS VARCHAR), ''),
                '|',
                ISNULL(CAST(quality_rating AS VARCHAR), ''),
                '|',
                ISNULL(CAST(price_rating AS VARCHAR), ''),
                '|',
                ISNULL(CAST(service_rating AS VARCHAR), ''),
                '|',
                ISNULL(CAST(recommendation AS VARCHAR), ''),
                '|',
                ISNULL(CAST(purchase_channel AS VARCHAR), ''),
                '|',
                ISNULL(CAST(customer_segment AS VARCHAR), ''),
                '|',
                ISNULL(CAST(comments AS VARCHAR), '')
            )
        ), 2)) AS row_hash,
        @current_date AS modified_date
    FROM DATN_Bronze_LH.dbo.m_survey
    ORDER BY id;


    DECLARE @max_modified DATETIME2(0);
    DECLARE @row_count INT;

    SELECT @max_modified = MAX(modified_date),
           @row_count = COUNT(*)
    FROM DATN_Silver_WH.dbo.survey;


    MERGE DATN_Silver_WH.dbo.water_mark AS target
    USING (SELECT 'survey' AS table_name, 'silver' AS layer_type) AS source
    ON target.table_name = source.table_name
       AND target.layer_type = source.layer_type
    WHEN MATCHED THEN
        UPDATE SET
            max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
    WHEN NOT MATCHED THEN
        INSERT (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('survey', @max_modified, 'silver', GETDATE(), @row_count);
END;
GO