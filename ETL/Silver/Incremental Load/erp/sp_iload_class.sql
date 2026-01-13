USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_class AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);



    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'class' AND layer_type = 'silver'; 


    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';


    IF OBJECT_ID('tempdb..#class_stg') IS NOT NULL DROP TABLE #class_stg;

    SELECT
        class_id,
        parent_class_id,
        class_code,
        class_name,
        class_level,
        sort_order,
        is_debit_normal,
        CAST(ModifiedDate AS DATETIME2(0)) AS modified_date
    INTO #class_stg
    FROM DATN_Bronze_LH.dbo.[class]
    WHERE CAST(ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;


    MERGE INTO DATN_Silver_WH.erp.[class] AS target
    USING #class_stg AS source
    ON target.class_id = source.class_id

    WHEN MATCHED THEN
        UPDATE SET
            target.parent_class_id = source.parent_class_id,
            target.class_code = source.class_code,
            target.class_name = source.class_name,
            target.class_level = source.class_level,
            target.sort_order = source.sort_order,
            target.is_debit_normal = source.is_debit_normal,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            class_id, parent_class_id, class_code, class_name,
            class_level, sort_order, is_debit_normal, modified_date
        )
        VALUES (
            source.class_id,
            source.parent_class_id,
            source.class_code,
            source.class_name,
            source.class_level,
            source.sort_order,
            source.is_debit_normal,
            source.modified_date
        );

    SELECT @rows_changed = @@ROWCOUNT;

 
    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #class_stg;

 
    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'class' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'class' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('class', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    -- Dọn dẹp bảng tạm
    DROP TABLE #class_stg;
END
GO