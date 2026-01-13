USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_customer AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.erp.customer

    INSERT INTO DATN_Silver_WH.erp.customer
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
        CAST(c.ModifiedDate AS DATETIME2(0)) AS modified_date
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
    WHERE c.CustomerID IS NOT NULL
    ORDER BY customer_id;

     -- Cập nhật watermark cho Silver layer
    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.[customer]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Silver_WH.erp.[customer]

    -- Update hoặc Insert watermark
    IF EXISTS (SELECT 1 FROM  DATN_Silver_WH.dbo.water_mark
               WHERE table_name = 'customer' AND layer_type = 'silver')
    BEGIN
        UPDATE  DATN_Silver_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'customer' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('customer', @max_modified, 'silver',  GETDATE(), @row_count)
    END
END;
GO