USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_department AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);



    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_department' AND layer_type = 'gold';

  
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#dim_department_stg') IS NOT NULL
        DROP TABLE #dim_department_stg;

    SELECT
        department_id,
        department_code,
        name,
        group_name,
        modified_date
    INTO #dim_department_stg
    FROM DATN_Silver_WH.erp.department
 
    WHERE modified_date > @MaxModifiedDate;

  

    MERGE INTO DATN_Gold_WH.dbo.dim_department AS target
    USING #dim_department_stg AS source
    ON target.department_key = source.department_id

    WHEN MATCHED THEN
        UPDATE SET
            target.department_code = source.department_code,
            target.name = source.name,
            target.group_name = source.group_name,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            department_key,
            department_code,
            name,
            group_name,
            modified_date
        )
        VALUES (
            source.department_id,
            source.department_code,
            source.name,
            source.group_name,
            source.modified_date
        );

    SELECT @rows_changed = @@ROWCOUNT;

    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #dim_department_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    -- Update hoặc Insert Watermark
    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_department' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_department' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_department', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END

    DROP TABLE #dim_department_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_department