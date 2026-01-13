USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_employee AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.erp.employee

    INSERT INTO DATN_Silver_WH.erp.employee
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
    ORDER BY e.BusinessEntityID;

     -- Cập nhật watermark cho Silver layer
    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.[employee]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.[employee]

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'employee' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'employee' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('employee', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END;
GO

-- EXEC erp.sp_fload_employee