USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_location AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE(); 
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);



   
    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'location' AND layer_type = 'silver';

    -- Nếu chưa có Watermark, đặt giá trị mặc định rất cũ
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#location_stg') IS NOT NULL DROP TABLE #location_stg;

    SELECT
        LocationID AS location_id,
        Name AS name,
        CostRate AS cost_rate,
        Availability AS availability,
        CAST(ModifiedDate AS DATETIME2(0)) AS modified_date,
        @CurrentLoadTime AS inserted_load_date 
    INTO #location_stg
    FROM DATN_Bronze_LH.dbo.location
    WHERE CAST(ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;



    MERGE INTO DATN_Silver_WH.erp.location AS target
    USING #location_stg AS source
    ON target.location_id = source.location_id

    WHEN MATCHED THEN
        UPDATE SET
            target.name = source.name,
            target.cost_rate = source.cost_rate,
            target.availability = source.availability,
            target.modified_date = source.modified_date
            

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            location_id, name, cost_rate, availability, modified_date
            -- , inserted_load_date
        )
        VALUES (
            source.location_id,
            source.name,
            source.cost_rate,
            source.availability,
            source.modified_date
            -- , source.inserted_load_date
        );


    SELECT @rows_changed = @@ROWCOUNT;

    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #location_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    -- Update hoặc Insert Watermark
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'location' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'location' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('location', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #location_stg;
END
GO