USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_product_inventory AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @watermark_date DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);




    SELECT @watermark_date = ISNULL(max_modified_date, '1900-01-01')
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'product_inventory' AND layer_type = 'silver';


    DECLARE @snapshot_date DATETIME2(0) = (
        SELECT MAX(CAST(ModifiedDate AS DATETIME2(0)))
        FROM DATN_Bronze_LH.dbo.product_inventory
    );

    IF @snapshot_date IS NULL
        SET @snapshot_date = @CurrentLoadTime;

   

    IF OBJECT_ID('tempdb..#opening_balance_stg') IS NOT NULL DROP TABLE #opening_balance_stg;
    IF OBJECT_ID('tempdb..#existing_balance_stg') IS NOT NULL DROP TABLE #existing_balance_stg;
    IF OBJECT_ID('tempdb..#new_txn_stg') IS NOT NULL DROP TABLE #new_txn_stg;
    IF OBJECT_ID('tempdb..#daily_agg_stg') IS NOT NULL DROP TABLE #daily_agg_stg;
    IF OBJECT_ID('tempdb..#calculated_balance_stg') IS NOT NULL DROP TABLE #calculated_balance_stg;
    IF OBJECT_ID('tempdb..#final_data_stg') IS NOT NULL DROP TABLE #final_data_stg;



    SELECT
        pi.ProductID,
        pi.LocationID,
        pi.Quantity AS opening_balance
    INTO #opening_balance_stg
    FROM DATN_Bronze_LH.dbo.product_inventory pi
    WHERE NOT EXISTS (
        SELECT 1
        FROM DATN_Silver_WH.erp.product_inventory si
        WHERE si.product_id = pi.ProductID
          AND si.location_id = pi.LocationID
    );



    SELECT
        product_id,
        location_id,
        unit_balance AS last_balance
    INTO #existing_balance_stg
    FROM (
        SELECT
            product_id,
            location_id,
            unit_balance,
            ROW_NUMBER() OVER (
                PARTITION BY product_id, location_id
                ORDER BY transaction_date DESC, modified_date DESC 
            ) AS rn
        FROM DATN_Silver_WH.erp.product_inventory
    ) latest
    WHERE rn = 1;



    SELECT
        th.TransactionID,
        th.ProductID,
        COALESCE(pi.LocationID, ob.LocationID) AS LocationID,
        CAST(th.TransactionDate AS DATE) AS transaction_date,
        CASE
            WHEN th.TransactionType IN ('P','W') THEN th.Quantity
            ELSE 0
        END AS Unit_in,
        CASE
            WHEN th.TransactionType IN ('S','I') THEN th.Quantity
            ELSE 0
        END AS Unit_out,
        th.ActualCost AS Unit_cost,
        CAST(th.ModifiedDate AS DATETIME2(0)) AS ModifiedDate
    INTO #new_txn_stg
    FROM DATN_Bronze_LH.dbo.product_transaction_history th
    LEFT JOIN DATN_Bronze_LH.dbo.product_inventory pi
        ON th.ProductID = pi.ProductID 
    LEFT JOIN #opening_balance_stg ob
        ON th.ProductID = ob.ProductID 
    WHERE CAST(th.ModifiedDate AS DATETIME2(0)) > @watermark_date
      AND CAST(th.TransactionDate AS DATE) >= CAST(@watermark_date AS DATE); 
    

    SELECT
        ProductID,
        LocationID,
        transaction_date,
        SUM(Unit_in) AS Unit_in,
        SUM(Unit_out) AS Unit_out,
        AVG(Unit_cost) AS Unit_cost,
        MAX(ModifiedDate) AS modified_date
    INTO #daily_agg_stg
    FROM #new_txn_stg
    WHERE LocationID IS NOT NULL
    GROUP BY ProductID, LocationID, transaction_date;


    SELECT
        da.ProductID,
        da.LocationID,
        da.transaction_date,
        da.Unit_in,
        da.Unit_out,
        da.Unit_cost,
        da.modified_date,
      
        SUM(da.Unit_in - da.Unit_out) OVER (
            PARTITION BY da.ProductID, da.LocationID
            ORDER BY da.transaction_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS incremental_movement
    INTO #calculated_balance_stg
    FROM #daily_agg_stg da;


    SELECT
        cb.ProductID AS product_id,
        cb.LocationID AS location_id,
        cb.transaction_date,
        cb.Unit_in,
        cb.Unit_out,
        cb.Unit_cost,
        COALESCE(eb.last_balance, ob.opening_balance, 0) + cb.incremental_movement AS unit_balance,
        cb.modified_date
    INTO #final_data_stg
    FROM #calculated_balance_stg cb
    LEFT JOIN #existing_balance_stg eb
        ON cb.ProductID = eb.product_id
        AND cb.LocationID = eb.location_id
    LEFT JOIN #opening_balance_stg ob
        ON cb.ProductID = ob.ProductID
        AND cb.LocationID = ob.LocationID

    UNION ALL


    SELECT
        ob.ProductID AS product_id,
        ob.LocationID AS location_id,
        @snapshot_date AS transaction_date, 
        0 AS unit_in,
        0 AS unit_out,
        0 AS unit_cost,
        ob.opening_balance AS unit_balance,
        @snapshot_date AS modified_date
    FROM #opening_balance_stg ob
    WHERE ob.opening_balance > 0
      AND NOT EXISTS (
 
        SELECT 1 FROM #calculated_balance_stg c
        WHERE c.ProductID = ob.ProductID AND c.LocationID = ob.LocationID
      );


 

    MERGE DATN_Silver_WH.erp.product_inventory AS target
    USING #final_data_stg AS source
    ON target.product_id = source.product_id
        AND target.location_id = source.location_id
        AND target.transaction_date = source.transaction_date

    WHEN MATCHED THEN
        UPDATE SET
            target.unit_in = source.unit_in,
            target.unit_out = source.unit_out,
            target.unit_cost = source.unit_cost,
            target.unit_balance = source.unit_balance,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            product_id, location_id, transaction_date, unit_in, unit_out,
            unit_cost, unit_balance, modified_date
        )
        VALUES (
            source.product_id, source.location_id, source.transaction_date,
            source.unit_in, source.unit_out, source.unit_cost,
            source.unit_balance, source.modified_date
        );

 
    SELECT @rows_changed = @@ROWCOUNT;

  
    SELECT @NewMaxModifiedDate = MAX(ModifiedDate)
    FROM #new_txn_stg;

 
    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @watermark_date;

    -- Update hoặc Insert Watermark
    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'product_inventory' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'product_inventory' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('product_inventory', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END


    DROP TABLE #opening_balance_stg;
    DROP TABLE #existing_balance_stg;
    DROP TABLE #new_txn_stg;
    DROP TABLE #daily_agg_stg;
    DROP TABLE #calculated_balance_stg;
    DROP TABLE #final_data_stg;

    SELECT
        @watermark_date AS previous_watermark,
        @NewMaxModifiedDate AS new_watermark,
        @rows_changed AS records_changed;

END
GO