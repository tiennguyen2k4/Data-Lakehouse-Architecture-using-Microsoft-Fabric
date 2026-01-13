USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_employee AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE(); 
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

    
    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'employee' AND layer_type = 'silver';

  
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';


    IF OBJECT_ID('tempdb..#employee_stg') IS NOT NULL DROP TABLE #employee_stg;

    SELECT
        e.BusinessEntityID AS employee_id,
        e.NationalIDNumber AS employee_national_number,
        CONCAT(p.FirstName, ' ', p.LastName) AS name,
        e.JobTitle AS position,
        CAST(e.BirthDate AS DATETIME2(0)) AS birth_day,
        e.Gender AS gender,
        ea.EmailAddress AS email,
        pp.PhoneNumber AS phone,
        COALESCE(a.AddressLine1, a.AddressLine2) AS address,
        CAST(e.HireDate AS DATETIME2(0)) AS start_date,
        CAST(edh.EndDate AS DATETIME2(0)) AS end_date,
        CASE WHEN e.CurrentFlag = 1 THEN 1 ELSE 0 END AS is_valid,
        CAST(e.ModifiedDate AS DATETIME2(0)) AS modified_date
    INTO #employee_stg
    FROM DATN_Bronze_LH.dbo.employee e
    INNER JOIN DATN_Bronze_LH.dbo.person p
        ON p.BusinessEntityID = e.BusinessEntityID
    LEFT JOIN (
        SELECT BusinessEntityID, EmailAddress,
            ROW_NUMBER() OVER (PARTITION BY BusinessEntityID ORDER BY EmailAddressID) AS rn
        FROM DATN_Bronze_LH.dbo.email_address
    ) ea ON ea.BusinessEntityID = e.BusinessEntityID AND ea.rn = 1
    LEFT JOIN (
        SELECT BusinessEntityID, PhoneNumber,
            ROW_NUMBER() OVER (PARTITION BY BusinessEntityID ORDER BY PhoneNumberTypeID) AS rn
        FROM DATN_Bronze_LH.dbo.person_phone
    ) pp ON pp.BusinessEntityID = e.BusinessEntityID AND pp.rn = 1
    LEFT JOIN DATN_Bronze_LH.dbo.employee_department_history edh
        ON e.BusinessEntityID = edh.BusinessEntityID
        AND edh.EndDate IS NULL
    LEFT JOIN (
        SELECT BusinessEntityID, AddressID,
            ROW_NUMBER() OVER (PARTITION BY BusinessEntityID ORDER BY AddressID) AS rn
        FROM DATN_Bronze_LH.dbo.business_entity_address
    ) bea ON bea.BusinessEntityID = e.BusinessEntityID AND bea.rn = 1
    LEFT JOIN DATN_Bronze_LH.dbo.address a
        ON a.AddressID = bea.AddressID

    WHERE CAST(e.ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;



    MERGE INTO DATN_Silver_WH.erp.employee AS target
    USING #employee_stg AS source
    ON target.employee_id = source.employee_id

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
            employee_id, employee_national_number, name, position,
            birth_day, gender, email, phone, address, start_date,
            end_date, is_valid, modified_date
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
    FROM #employee_stg;

 
    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    -- Update hoặc Insert Watermark
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'employee' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'employee' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('employee', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    -- Dọn dẹp bảng tạm
    DROP TABLE #employee_stg;
END
GO