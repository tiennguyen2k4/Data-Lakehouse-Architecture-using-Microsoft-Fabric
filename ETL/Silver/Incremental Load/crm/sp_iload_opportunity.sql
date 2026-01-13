USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE crm.sp_iload_opportunity AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @current_date DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0; -- Biến đếm tổng số dòng thay đổi (INSERT + UPDATE)

    -- 1. Tạo bảng tạm #s1 và load dữ liệu từ nguồn (Bronze)
    IF OBJECT_ID('tempdb..#s1') IS NOT NULL DROP TABLE #s1;

    SELECT
        o.opportunity_key,
        o.opportunity_id,
        c.customer_id,
        o.opportunity_stage,
        o.estimated_value,
        o.close_date,
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
        @current_date AS modified_date
    INTO #s1
    FROM DATN_Bronze_LH.dbo.opportunity o
    JOIN DATN_Silver_WH.erp.customer c ON c.customer_crm_id = o.lead_id;

    -- 2. MERGE và lấy @@ROWCOUNT
    MERGE INTO DATN_Silver_WH.crm.opportunity AS target
    USING #s1 AS source
    ON target.opportunity_key = source.opportunity_key

    WHEN MATCHED AND target.row_hash <> source.row_hash THEN
        UPDATE SET
            target.opportunity_id = source.opportunity_id,
            target.customer_id = source.customer_id,
            target.opportunity_stage = source.opportunity_stage,
            target.estimated_value = source.estimated_value,
            target.close_date = source.close_date,
            target.row_hash = source.row_hash,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            opportunity_key, opportunity_id, customer_id, opportunity_stage, estimated_value, close_date, row_hash, modified_date
        )
        VALUES (
            source.opportunity_key, source.opportunity_id, source.customer_id, source.opportunity_stage, source.estimated_value, source.close_date, source.row_hash, source.modified_date
        );

    -- Lấy tổng số dòng bị ảnh hưởng (INSERTED + UPDATED)
    SELECT @rows_changed = @@ROWCOUNT;

    -------------------------------------------------------------------------
    -- 3. Cập nhật Watermark
    -------------------------------------------------------------------------

    DECLARE @new_max_date DATETIME2(0);

    SELECT @new_max_date = MAX(modified_date)
    FROM DATN_Bronze_LH.dbo.opportunity;

    -- Update hoặc Insert watermark, sử dụng @rows_changed
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'opportunity' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @new_max_date,
            last_load_time = @current_date,
            row_count = @rows_changed -- Tổng số dòng INSERTED + UPDATED
        WHERE table_name = 'opportunity' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('opportunity', @new_max_date, 'silver', @current_date, @rows_changed)
    END

    DROP TABLE #s1
END
GO