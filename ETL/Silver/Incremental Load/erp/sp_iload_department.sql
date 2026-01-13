USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_department AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE(); 
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

    
    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'department' AND layer_type = 'silver';

    -- Nếu chưa có Watermark, đặt giá trị mặc định rất cũ
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#dept_stg') IS NOT NULL DROP TABLE #dept_stg;

    SELECT
        DepartmentID AS department_id,
        Name AS department_code,
        Name AS name,
        GroupName AS group_name,
        CAST(ModifiedDate AS DATETIME2(0)) AS modified_date,
        @CurrentLoadTime AS inserted_load_date 
    INTO #dept_stg
    FROM DATN_Bronze_LH.dbo.department
    WHERE CAST(ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;

  

    MERGE INTO DATN_Silver_WH.erp.department AS target
    USING #dept_stg AS source
    ON target.department_id = source.department_id

    WHEN MATCHED THEN
        UPDATE SET
            target.department_code = source.department_code,
            target.name = source.name,
            target.group_name = source.group_name,
            target.modified_date = source.modified_date
            

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            department_id, department_code, name, group_name,
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
    FROM #dept_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    -- Update hoặc Insert Watermark
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'department' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'department' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('department', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    -- Dọn dẹp bảng tạm
    DROP TABLE #dept_stg;
END
GO