USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_budget AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;

    -------------------------------------------------------------------------
    -- 1. Tính Hash và tải toàn bộ dữ liệu nguồn vào Bảng Tạm (#budget_stg)
    -------------------------------------------------------------------------

    IF OBJECT_ID('tempdb..#budget_stg') IS NOT NULL DROP TABLE #budget_stg;

    SELECT
        account_id,
        department_id,
        [date] AS budget_date,
        budget,
        -- Tính MD5 hash của toàn bộ các cột chính
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
        @CurrentLoadTime AS modified_date -- Ghi lại thời điểm tải
    INTO #budget_stg
    FROM DATN_Bronze_LH.dbo.m_budget;

    -------------------------------------------------------------------------
    -- 2. MERGE với Hash Comparison
    -------------------------------------------------------------------------

    MERGE INTO DATN_Silver_WH.dbo.budget AS target
    USING #budget_stg AS source
    ON target.account_id = source.account_id
        AND target.department_id = source.department_id
        AND target.budget_date = source.budget_date

    -- UPDATE nếu hash khác (dữ liệu thay đổi)
    WHEN MATCHED AND target.row_hash <> source.row_hash THEN
        UPDATE SET
            target.budget = source.budget,
            target.row_hash = source.row_hash,
            target.modified_date = source.modified_date

    -- INSERT record mới
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            account_id,
            department_id,
            budget_date,
            budget,
            row_hash,
            modified_date
        )
        VALUES (
            source.account_id,
            source.department_id,
            source.budget_date,
            source.budget,
            source.row_hash,
            source.modified_date
        )

    -- XỬ LÝ DELETE: Xóa các bản ghi đã không còn tồn tại trong nguồn (nếu cần)
    -- Giả định ta không cần xóa các bản ghi cũ của ngân sách, nếu cần thì thêm WHEN NOT MATCHED BY SOURCE.
    ;

    -- Lấy tổng số dòng bị ảnh hưởng (INSERTED + UPDATED)
    SELECT @rows_changed = @@ROWCOUNT;

    -------------------------------------------------------------------------
    -- 3. Cập nhật Watermark (Thời gian tải)
    -------------------------------------------------------------------------

    -- Cập nhật Watermark: Vì là Full Load, ta chỉ cập nhật thời gian tải và số dòng
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'budget' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @CurrentLoadTime, -- Sử dụng thời điểm tải làm Watermark
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'budget' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('budget', @CurrentLoadTime, 'silver', @CurrentLoadTime, @rows_changed)
    END

    -- Dọn dẹp bảng tạm
    DROP TABLE #budget_stg;
END
GO