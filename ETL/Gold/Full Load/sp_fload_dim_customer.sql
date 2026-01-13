USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_dim_customer AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Gold_WH.dbo.dim_customer

    INSERT INTO DATN_Gold_WH.dbo.dim_customer
    SELECT customer_id, customer_erp_id, customer_crm_id, name, email, phone,
    address, birth_day, gender, is_lead, is_person, modified_date
    FROM DATN_Silver_WH.erp.customer
    ORDER BY customer_id;

    DECLARE @max_modified DATETIME2(0)
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[dim_customer]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[dim_customer]

    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_customer' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'dim_customer' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_customer', @max_modified, 'gold',  GETDATE(), @row_count)
    END

END;
GO

-- EXEC dbo.sp_fload_dim_customer