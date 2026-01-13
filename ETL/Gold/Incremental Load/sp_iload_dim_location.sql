USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_location AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);


    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_location' AND layer_type = 'gold';

    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#dim_location_stg') IS NOT NULL
        DROP TABLE #dim_location_stg;

    SELECT
        location_id,
        name,
        cost_rate,
        availability,
        modified_date
    INTO #dim_location_stg
    FROM DATN_Silver_WH.erp.location

    WHERE modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.dim_location AS target
    USING #dim_location_stg AS source
    ON target.location_key = source.location_id

    WHEN MATCHED THEN
        UPDATE SET
            target.name = source.name,
            target.cost_rate = source.cost_rate,
            target.availability = source.availability,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            location_key,
            name,
            cost_rate,
            availability,
            modified_date
        )
        VALUES (
            source.location_id,
            source.name,
            source.cost_rate,
            source.availability,
            source.modified_date
        );

 
    SELECT @rows_changed = @@ROWCOUNT;

  
    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #dim_location_stg;

    
    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;


    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_location' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_location' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_location', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #dim_location_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_location