USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_fload_fact_budget
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE DATN_Gold_WH.dbo.fact_budget;

    INSERT INTO DATN_Gold_WH.dbo.fact_budget (
        account_key,
        department_key,
        budget_date_key,
        budget,
        modified_date
    )
    SELECT
        c.account_key,
        dp.department_key,
        d.date_key AS budget_date_key,
        b.budget,
        b.modified_date
    FROM DATN_Silver_WH.dbo.budget b
    LEFT JOIN DATN_Gold_WH.dbo.dim_date d ON d.[date] = b.budget_date
    LEFT JOIN DATN_Gold_WH.dbo.dim_account c ON c.account_key=b.account_id
    LEFT JOIN DATN_Gold_WH.dbo.dim_department dp ON dp.department_key=b.department_id;


    DECLARE @max_modified DATETIME
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Gold_WH.dbo.[fact_budget]

    DECLARE @row_count INT
    SELECT @row_count = COUNT(*)
    FROM DATN_Gold_WH.dbo.[fact_budget]


    IF EXISTS (SELECT 1 FROM  DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'fact_budget' AND layer_type = 'gold')
    BEGIN
        UPDATE  DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @max_modified,
            last_load_time = GETDATE(),
            row_count = @row_count
        WHERE table_name = 'fact_budget' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO  DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('fact_budget', @max_modified, 'gold',  GETDATE(), @row_count)
    END
END
GO

-- EXEC dbo.sp_fload_fact_budget;
