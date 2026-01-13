USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_customer AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

  

    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'customer' AND layer_type = 'silver';

    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';


    IF OBJECT_ID('tempdb..#customer_stg') IS NOT NULL DROP TABLE #customer_stg;

    SELECT
        c.CustomerID AS customer_id,
        c.CustomerID AS customer_erp_id,
        ccrm.lead_id AS customer_crm_id,
        CASE
            WHEN c.PersonID IS NOT NULL THEN p.FirstName + ' ' + p.LastName
            WHEN c.StoreID IS NOT NULL THEN s.Name
            ELSE 'Unknown Customer'
        END AS name,
        e.EmailAddress AS email,
        pp.PhoneNumber AS phone,
        COALESCE(a.AddressLine1, a.AddressLine2) AS address,
        CAST(p.BirthDate AS DATE) AS birth_day,
        p.Gender AS gender,
        CASE
            WHEN ccrm.lead_id IS NULL THEN 0
            ELSE 1
        END AS is_lead,
        CASE
            WHEN c.PersonID IS NULL THEN 0
            ELSE 1
        END AS is_person,
        CAST(c.ModifiedDate AS DATETIME2(0)) AS modified_date,
        @CurrentLoadTime AS inserted_load_date
    INTO #customer_stg
    FROM DATN_Bronze_LH.dbo.customer c
    LEFT JOIN DATN_Bronze_LH.dbo.leads ccrm
        ON c.CustomerID = CAST(RIGHT(ccrm.lead_id, 4) AS INT)
    LEFT JOIN DATN_Bronze_LH.dbo.person p
        ON p.BusinessEntityID = c.PersonID
    LEFT JOIN DATN_Bronze_LH.dbo.store s
        ON s.BusinessEntityID = c.StoreID
    LEFT JOIN DATN_Bronze_LH.dbo.email_address e
        ON e.BusinessEntityID = COALESCE(c.PersonID, c.StoreID)
    LEFT JOIN DATN_Bronze_LH.dbo.person_phone pp
        ON pp.BusinessEntityID = c.PersonID
    LEFT JOIN (
        SELECT
            ba.BusinessEntityID,
            ba.AddressID,
            ROW_NUMBER() OVER (PARTITION BY ba.BusinessEntityID ORDER BY ba.AddressID) AS rn
        FROM DATN_Bronze_LH.dbo.business_entity_address ba
    ) ba ON ba.BusinessEntityID = COALESCE(c.PersonID, c.StoreID) AND ba.rn = 1
    LEFT JOIN DATN_Bronze_LH.dbo.address a
        ON a.AddressID = ba.AddressID
    -- QUAN TRỌNG: WHERE phải đi SAU tất cả các JOIN
    WHERE c.CustomerID IS NOT NULL
      AND CAST(c.ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;



    MERGE INTO DATN_Silver_WH.erp.customer AS target
    USING #customer_stg AS source
    ON target.customer_id = source.customer_id

    WHEN MATCHED THEN
        UPDATE SET
            target.customer_erp_id = source.customer_erp_id,
            target.customer_crm_id = source.customer_crm_id,
            target.name = source.name,
            target.email = source.email,
            target.phone = source.phone,
            target.address = source.address,
            target.birth_day = source.birth_day,
            target.gender = source.gender,
            target.is_lead = source.is_lead,
            target.is_person = source.is_person,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            customer_id, customer_erp_id, customer_crm_id, name, email,
            phone, address, birth_day, gender, is_lead, is_person,
            modified_date
        )
        VALUES (
            source.customer_id,
            source.customer_erp_id,
            source.customer_crm_id,
            source.name,
            source.email,
            source.phone,
            source.address,
            source.birth_day,
            source.gender,
            source.is_lead,
            source.is_person,
            source.modified_date
        );

    SELECT @rows_changed = @@ROWCOUNT;

   

    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #customer_stg;

    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'customer' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'customer' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('customer', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    DROP TABLE #customer_stg;
END
GO