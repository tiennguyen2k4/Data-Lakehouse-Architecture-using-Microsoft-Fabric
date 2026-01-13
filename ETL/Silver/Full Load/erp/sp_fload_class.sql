USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_class AS

BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE DATN_Silver_WH.erp.[class]

    INSERT INTO DATN_Silver_WH.erp.[class]
    SELECT class_id, parent_class_id, class_code, class_name,
        class_level , sort_order, is_debit_normal, CAST(ModifiedDate AS DATETIME2(0))
    FROM DATN_Bronze_LH.dbo.[class]
    ORDER BY class_id;

     -- Cập nhật watermark cho Silver layer
    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.[class]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.[class]

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'class' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'class' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('class', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END;
GO

-- EXEC erp.sp_fload_class