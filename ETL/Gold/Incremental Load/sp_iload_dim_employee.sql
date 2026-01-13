USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_employee AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);



    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_employee' AND layer_type = 'gold';


    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#dim_employee_stg') IS NOT NULL
        DROP TABLE #dim_employee_stg;

    SELECT
        employee_id,
        employee_national_number,
        name,
        position,
        birth_day,
        gender,
        email,
        phone,
        address,
        start_date,
        end_date,
        is_valid,
        modified_date
    INTO #dim_employee_stg
    FROM DATN_Silver_WH.erp.employee

    WHERE modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.dim_employee AS target
    USING #dim_employee_stg AS source
    ON target.employee_key = source.employee_id

    WHEN MATCHED THEN
        UPDATE SET
            target.employee_national_number = source.employee_national_number,
            target.name = source.name,
            target.position = source.position,
            target.birth_day = source.birth_day,
            target.gender = source.gender,
            target.email = source.email,
            target.phone = source.phone,
            target.address = source.address,
            target.start_date = source.start_date,
            target.end_date = source.end_date,
            target.is_valid = source.is_valid,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            employee_key,
            employee_national_number,
            name,
            position,
            birth_day,
            gender,
            email,
            phone,
            address,
            start_date,
            end_date,
            is_valid,
            modified_date
        )
        VALUES (
            source.employee_id,
            source.employee_national_number,
            source.name,
            source.position,
            source.birth_day,
            source.gender,
            source.email,
            source.phone,
            source.address,
            source.start_date,
            source.end_date,
            source.is_valid,
            source.modified_date
        );

    
    SELECT @rows_changed = @@ROWCOUNT;

  
    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #dim_employee_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_employee' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_employee' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_employee', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #dim_employee_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_employee