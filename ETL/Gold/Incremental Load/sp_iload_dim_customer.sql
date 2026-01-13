USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_customer AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);



    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_customer' AND layer_type = 'gold';

 
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';


    IF OBJECT_ID('tempdb..#dim_customer_stg') IS NOT NULL
        DROP TABLE #dim_customer_stg;

    SELECT
        customer_id,
        customer_erp_id,
        customer_crm_id,
        name,
        email,
        phone,
        address,
        birth_day,
        gender,
        is_lead,
        is_person,
        modified_date
    INTO #dim_customer_stg
    FROM DATN_Silver_WH.erp.customer

    WHERE modified_date > @MaxModifiedDate;

  

    MERGE INTO DATN_Gold_WH.dbo.dim_customer AS target
    USING #dim_customer_stg AS source
    ON target.customer_key = source.customer_id

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
            customer_key, customer_erp_id, customer_crm_id, name, email,
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
    FROM #dim_customer_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_customer' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_customer' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_customer', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #dim_customer_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_customer