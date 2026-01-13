USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_fload_product_inventory AS
BEGIN
    --SET NOCOUNT ON;
    TRUNCATE TABLE DATN_Silver_WH.erp.product_inventory;

    -- Step 1: Lấy snapshot date
    DECLARE @snapshot_date DATE = (
        SELECT MAX(CAST(ModifiedDate AS DATE))
        FROM DATN_Bronze_LH.dbo.product_inventory
    );

    -- Step 2: Lấy opening balance (số dư tại snapshot date)
    WITH opening_balance AS (
        SELECT
            pi.ProductID,
            pi.LocationID,
            pi.Quantity as opening_balance
        FROM DATN_Bronze_LH.dbo.product_inventory pi
    )
    ,

    -- Step 3: Lấy ALL transactions
    all_transactions AS (
        SELECT
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
            th.ModifiedDate
        FROM DATN_Bronze_LH.dbo.product_transaction_history th
        LEFT JOIN DATN_Bronze_LH.dbo.product_inventory pi
            ON th.ProductID = pi.ProductID
        LEFT JOIN opening_balance ob
            ON th.ProductID = ob.ProductID
        WHERE CAST(th.TransactionDate AS DATE) <= @snapshot_date
    )
    ,

    -- Step 4: Aggregate by day
    daily_agg AS (
        SELECT
            ProductID,
            LocationID,
            transaction_date,
            SUM(Unit_in) AS Unit_in,
            SUM(Unit_out) AS Unit_out,
            AVG(Unit_cost) AS Unit_cost,
            MAX(ModifiedDate) AS modified_date
        FROM all_transactions
        WHERE LocationID IS NOT NULL
        GROUP BY ProductID, LocationID, transaction_date
    )
    ,

    -- Step 5: Calculate running balance từ transactions
    running_balance AS (
        SELECT
            ProductID,
            LocationID,
            transaction_date,
            Unit_in,
            Unit_out,
            Unit_cost,
            modified_date,
            SUM(Unit_in - Unit_out) OVER (
                PARTITION BY ProductID, LocationID
                ORDER BY transaction_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS running_balance
        FROM daily_agg
    )
    ,

    -- Step 6: Tính adjustment factor
    -- Đây là chênh lệch giữa opening_balance và running_balance tại snapshot date
    adjustment_calc AS (
        SELECT
            rb.ProductID,
            rb.LocationID,
            ob.opening_balance - MAX(rb.running_balance) as adjustment
        FROM running_balance rb
        INNER JOIN opening_balance ob
            ON rb.ProductID = ob.ProductID
            AND rb.LocationID = ob.LocationID
        WHERE rb.transaction_date = @snapshot_date
        GROUP BY rb.ProductID, rb.LocationID, ob.opening_balance
    )
    ,

    -- Step 7: Apply adjustment
    final_inventory AS (
        SELECT
            rb.ProductID,
            rb.LocationID,
            rb.transaction_date,
            rb.Unit_in,
            rb.Unit_out,
            rb.Unit_cost,
            rb.modified_date,
            rb.running_balance + ISNULL(ac.adjustment, 0) AS Unit_balance
        FROM running_balance rb
        LEFT JOIN adjustment_calc ac
            ON rb.ProductID = ac.ProductID
            AND rb.LocationID = ac.LocationID
    )

    -- Step 8: Insert final data
    INSERT INTO DATN_Silver_WH.erp.product_inventory
        (product_id, location_id, transaction_date, unit_in, unit_out, unit_cost, unit_balance, modified_date)
    SELECT
        ProductID,
        LocationID,
        transaction_date,
        Unit_in,
        Unit_out,
        Unit_cost,
        Unit_balance,
        modified_date
    FROM final_inventory
    ORDER BY transaction_date, ProductID;

    -- Debug: Check row count
    DECLARE @row_count INT;
    SELECT @row_count = COUNT(*) FROM DATN_Silver_WH.erp.product_inventory;

    -- Watermark update
    DECLARE @max_modified DATETIME;
    SELECT @max_modified = MAX(modified_date)
    FROM DATN_Silver_WH.erp.product_inventory;

    IF @max_modified IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM DATN_Silver_WH.dbo.water_mark
                   WHERE table_name = 'product_inventory' AND layer_type = 'silver')
        BEGIN
            UPDATE DATN_Silver_WH.dbo.water_mark
            SET max_modified_date = @max_modified,
                last_load_time = GETDATE(),
                row_count = @row_count
            WHERE table_name = 'product_inventory' AND layer_type = 'silver';
        END
        ELSE
        BEGIN
            INSERT INTO DATN_Silver_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
            VALUES ('product_inventory', @max_modified, 'silver', GETDATE(), @row_count);
        END
    END
END
GO