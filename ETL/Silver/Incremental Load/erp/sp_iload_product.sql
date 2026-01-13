USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_iload_product AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);


    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Silver_WH.dbo.water_mark
    WHERE table_name = 'product' AND layer_type = 'silver';

    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';

    IF OBJECT_ID('tempdb..#product_stg') IS NOT NULL DROP TABLE #product_stg;

    SELECT
        p.ProductID AS product_id,
        p.Name AS name,
        pc.Name AS category,
        ps.Name AS subcategory,
        p.ProductNumber AS model,
        p.ProductLine AS line,
        p.Class AS class,
        p.Style AS style,
        p.Color AS color,
        p.Size AS size,
        p.Weight AS weight,
        ISNULL(pd.Description, p.Name) AS description,
        p.StandardCost AS standard_cost,
        p.ListPrice AS list_price,
        p.MakeFlag AS make_flag,
        p.FinishedGoodsFlag AS finished_goods_flag,
        p.SafetyStockLevel AS safety_stock_level,
        p.ReorderPoint AS reorder_point,
        p.DaysToManufacture AS days_to_manufacture,
        CAST(p.SellStartDate AS DATETIME2(0)) AS sell_start_date,
        CAST(p.SellEndDate AS DATETIME2(0)) AS sell_end_date,
        CAST(p.ModifiedDate AS DATETIME2(0)) AS modified_date,
        @CurrentLoadTime AS inserted_load_date
    INTO #product_stg
    FROM DATN_Bronze_LH.dbo.product p
    LEFT JOIN DATN_Bronze_LH.dbo.product_sub_category ps
        ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    LEFT JOIN DATN_Bronze_LH.dbo.product_category pc
        ON ps.ProductCategoryID = pc.ProductCategoryID
    LEFT JOIN DATN_Bronze_LH.dbo.product_model pm
        ON p.ProductModelID = pm.ProductModelID
    LEFT JOIN DATN_Bronze_LH.dbo.product_model_description_culture pmpdc
        ON pm.ProductModelID = pmpdc.ProductModelID
        AND pmpdc.CultureID = 'en'
    LEFT JOIN DATN_Bronze_LH.dbo.product_description pd
        ON pmpdc.ProductDescriptionID = pd.ProductDescriptionID
    WHERE CAST(p.ModifiedDate AS DATETIME2(0)) > @MaxModifiedDate;


    MERGE INTO DATN_Silver_WH.erp.product AS target
    USING #product_stg AS source
    ON target.product_id = source.product_id

    WHEN MATCHED THEN
        UPDATE SET
            target.name = source.name,
            target.category = source.category,
            target.subcategory = source.subcategory,
            target.model = source.model,
            target.line = source.line,
            target.class = source.class,
            target.style = source.style,
            target.color = source.color,
            target.size = source.size,
            target.weight = source.weight,
            target.description = source.description,
            target.standard_cost = source.standard_cost,
            target.list_price = source.list_price,
            target.make_flag = source.make_flag,
            target.finished_goods_flag = source.finished_goods_flag,
            target.safety_stock_level = source.safety_stock_level,
            target.reorder_point = source.reorder_point,
            target.days_to_manufacture = source.days_to_manufacture,
            target.sell_start_date = source.sell_start_date,
            target.sell_end_date = source.sell_end_date,
            target.modified_date = source.modified_date

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            product_id, name, category, subcategory, model, line, class,
            style, color, size, weight, description, standard_cost,
            list_price, make_flag, finished_goods_flag, safety_stock_level,
            reorder_point, days_to_manufacture, sell_start_date,
            sell_end_date, modified_date
        )
        VALUES (
            source.product_id,
            source.name,
            source.category,
            source.subcategory,
            source.model,
            source.line,
            source.class,
            source.style,
            source.color,
            source.size,
            source.weight,
            source.description,
            source.standard_cost,
            source.list_price,
            source.make_flag,
            source.finished_goods_flag,
            source.safety_stock_level,
            source.reorder_point,
            source.days_to_manufacture,
            source.sell_start_date,
            source.sell_end_date,
            source.modified_date
        );

    SELECT @rows_changed = @@ROWCOUNT;


    SELECT @NewMaxModifiedDate = MAX(modified_date)
    FROM #product_stg;

    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    IF EXISTS (SELECT 1 FROM dbo.water_mark
                WHERE table_name = 'product' AND layer_type = 'silver')
    BEGIN
        UPDATE dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'product' AND layer_type = 'silver'
    END
    ELSE
    BEGIN
        INSERT INTO dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('product', @NewMaxModifiedDate, 'silver', @CurrentLoadTime, @rows_changed)
    END

    DROP TABLE #product_stg;
END
GO