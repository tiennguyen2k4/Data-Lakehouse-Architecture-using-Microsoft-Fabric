USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_class AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

   

    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_class' AND layer_type = 'gold';

   
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';


    IF OBJECT_ID('tempdb..#dim_class_stg') IS NOT NULL
        DROP TABLE #dim_class_stg;

    SELECT
        class_id,
        parent_class_id,
        class_code,
        class_name,
        class_level,
        sort_order,
        is_debit_normal,
        modified_date
    INTO #dim_class_stg
    FROM DATN_Silver_WH.erp.[class]
   
    WHERE modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.dim_class AS target
    USING #dim_class_stg AS source
    ON target.class_key = source.class_id

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
            class_key,
            parent_class_id,
            class_code,
            class_name,
            class_level,
            sort_order,
            is_debit_normal,
            modified_date
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
    FROM #dim_class_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_class' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_class' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_class', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #dim_class_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_class