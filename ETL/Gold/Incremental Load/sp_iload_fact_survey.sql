USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_fact_survey
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
    WHERE table_name = 'fact_survey' AND layer_type = 'gold';


    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#fact_survey_stg') IS NOT NULL
        DROP TABLE #fact_survey_stg;

    SELECT
        s.survey_id AS survey_key,  
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
    INTO #fact_survey_stg
    FROM DATN_Silver_WH.dbo.survey s
    LEFT JOIN DATN_Gold_WH.dbo.dim_customer c
        ON c.customer_key = s.customer_id  
    LEFT JOIN DATN_Gold_WH.dbo.dim_product p
        ON p.product_key = s.product_id  
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d
        ON d.[date] = s.survey_date

    WHERE s.modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.fact_survey AS target  
    USING #fact_survey_stg AS source  
    ON target.survey_key = source.survey_key

    WHEN MATCHED THEN
        UPDATE SET
            target.survey_code = source.survey_code,
            target.customer_key = source.customer_key,
            target.product_key = source.product_key,
            target.survey_date_key = source.date_key,
            target.overall_rating = source.overall_rating,
            target.quality_rating = source.quality_rating,  
            target.price_rating = source.price_rating,
            target.service_rating = source.service_rating,
            target.recommendation = source.recommendation,
            target.purchase_channel = source.purchase_channel,
            target.customers_segment = source.customers_segment,  
            target.comments = source.comments,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            survey_key,
            survey_code,
            customer_key,
            product_key,
            survey_date_key,
            overall_rating,
            quality_rating,
            price_rating,
            service_rating,
            recommendation,
            purchase_channel,
            customers_segment,
            comments,
            modified_date
        )
        VALUES (
            source.survey_key,  
            source.survey_code,
            source.customer_key,
            source.product_key,
            source.date_key,
            source.overall_rating,
            source.quality_rating,
            source.price_rating,
            source.service_rating,
            source.recommendation,
            source.purchase_channel,
            source.customers_segment,
            source.comments,
            source.modified_date
        );


    SELECT @rows_changed = @@ROWCOUNT;


    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #fact_survey_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_survey' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'fact_survey' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_survey', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #fact_survey_stg;

END;
GO

-- EXEC dbo.sp_iload_fact_survey