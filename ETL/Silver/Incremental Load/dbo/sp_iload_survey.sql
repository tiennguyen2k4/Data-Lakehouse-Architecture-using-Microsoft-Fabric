USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_survey AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;

    -------------------------------------------------------------------------
    -- 1. Tính Hash và tải toàn bộ dữ liệu nguồn vào Bảng Tạm (#survey_stg)
    -------------------------------------------------------------------------

    IF OBJECT_ID('tempdb..#survey_stg') IS NOT NULL DROP TABLE #survey_stg;

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
        customer_segment,
        comments,
        -- Tính MD5 hash của toàn bộ các cột
        LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5',
            CONCAT(
                ISNULL(CAST(survey_code AS VARCHAR), ''), '|',
                ISNULL(CAST(customer_id AS VARCHAR), ''), '|',
                ISNULL(CAST(product_id AS VARCHAR), ''), '|',
                ISNULL(CONVERT(VARCHAR, survey_date, 120), ''), '|',
                ISNULL(CAST(overall_rating AS VARCHAR), ''), '|',
                ISNULL(CAST(quality_rating AS VARCHAR), ''), '|',
                ISNULL(CAST(price_rating AS VARCHAR), ''), '|',
                ISNULL(CAST(service_rating AS VARCHAR), ''), '|',
                ISNULL(CAST(recommendation AS VARCHAR), ''), '|',
                ISNULL(CAST(purchase_channel AS VARCHAR), ''), '|',
                ISNULL(CAST(customer_segment AS VARCHAR), ''), '|',
                ISNULL(CAST(comments AS VARCHAR), '')
            )
        ), 2)) AS row_hash,
        @CurrentLoadTime AS modified_date -- Ghi lại thời điểm tải
    INTO #survey_stg
    FROM DATN_Bronze_LH.dbo.m_survey;

    -------------------------------------------------------------------------
    -- 2. MERGE với Hash Comparison
    -------------------------------------------------------------------------

    MERGE INTO DATN_Silver_WH.dbo.survey AS target
    USING #survey_stg AS source
    ON target.survey_id = source.survey_id

    WHEN MATCHED AND target.row_hash <> source.row_hash THEN
        UPDATE SET
            target.survey_code = source.survey_code,
            target.customer_id = source.customer_id,
            target.product_id = source.product_id,
            target.survey_date = source.survey_date,
            target.overall_rating = source.overall_rating,
            target.quality_rating = source.quality_rating,
            target.price_rating = source.price_rating,
            target.service_rating = source.service_rating,
            target.recommendation = source.recommendation,
            target.purchase_channel = source.purchase_channel,
            target.customers_segment = source.customer_segment, -- Sửa lỗi chính tả cột customers_segment thành customer_segment
            target.comments = source.comments,
            target.row_hash = source.row_hash,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            survey_id, survey_code, customer_id, product_id, survey_date,
            overall_rating, quality_rating, price_rating, service_rating,
            recommendation, purchase_channel, customers_segment, comments,
            row_hash, modified_date -- Thêm hash và modified_date
        )
        VALUES (
            source.survey_id,
            source.survey_code,
            source.customer_id,
            source.product_id,
            source.survey_date,
            source.overall_rating,
            source.quality_rating,
            source.price_rating,
            source.service_rating,
            source.recommendation,
            source.purchase_channel,
            source.customer_segment, -- Sửa lỗi chính tả
            source.comments,
            source.row_hash,
            source.modified_date
        );

    -- Lấy tổng số dòng bị ảnh hưởng (INSERTED + UPDATED)
    SELECT @rows_changed = @@ROWCOUNT;

    -------------------------------------------------------------------------
    -- 3. Cập nhật Watermark (Thời gian tải)
    -------------------------------------------------------------------------

    -- Cập nhật Watermark: Vì là Full Load + Hash, ta cập nhật thời gian tải và số dòng
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'survey' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @CurrentLoadTime, -- Sử dụng thời điểm tải làm Watermark
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'survey' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('survey', @CurrentLoadTime, 'silver', @CurrentLoadTime, @rows_changed)
    END

    -- Dọn dẹp bảng tạm
    DROP TABLE #survey_stg;
END
GO