USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_dim_employee AS

BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Gold_WH.dbo.dim_employee

    INSERT INTO DATN_Gold_WH.dbo.dim_employee
    SELECT employee_id, employee_national_number, name,
    position, birth_day, gender, email, phone, address, start_date,
    end_date, is_valid, modified_date
    FROM DATN_Silver_WH.erp.employee
    ORDER BY employee_id;


    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[dim_employee]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[dim_employee]


    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_employee' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'dim_employee' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_employee', @max_modified, 'gold',  GETDATE(), @row_count)
    END

END;
GO

-- EXEC dbo.sp_fload_dim_employee