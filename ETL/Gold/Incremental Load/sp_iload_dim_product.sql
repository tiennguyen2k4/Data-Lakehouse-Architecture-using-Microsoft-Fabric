USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_iload_dim_product AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxModifiedDate DATETIME2(0);
    DECLARE @CurrentLoadTime DATETIME2(0) = GETDATE();
    DECLARE @rows_changed INT = 0;
    DECLARE @NewMaxModifiedDate DATETIME2(0);

 

    SELECT @MaxModifiedDate = max_modified_date
    FROM DATN_Gold_WH.dbo.water_mark
    WHERE table_name = 'dim_product' AND layer_type = 'gold';

   
    IF @MaxModifiedDate IS NULL
        SET @MaxModifiedDate = '1900-01-01 00:00:00';



    IF OBJECT_ID('tempdb..#dim_product_stg') IS NOT NULL
        DROP TABLE #dim_product_stg;

    SELECT
        product_id,
        name,
        category,
        subcategory,
        model,
        line,
        class,
        style,
        color,
        size,
        weight,
        description,
        standard_cost,
        list_price,
        make_flag,
        finished_goods_flag,
        safety_stock_level,
        reorder_point,
        days_to_manufacture,
        sell_start_date,
        sell_end_date,
        modified_date
    INTO #dim_product_stg
    FROM DATN_Silver_WH.erp.product

    WHERE modified_date > @MaxModifiedDate;



    MERGE INTO DATN_Gold_WH.dbo.dim_product AS target
    USING #dim_product_stg AS source
    ON target.product_key = source.product_id

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
            product_key, name, category, subcategory, model, line,
            class, style, color, size, weight, description, standard_cost,
            list_price, make_flag, finished_goods_flag, safety_stock_level,
            reorder_point, days_to_manufacture, sell_start_date, sell_end_date,
            modified_date
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
    FROM #dim_product_stg;


    IF @NewMaxModifiedDate IS NULL
        SET @NewMaxModifiedDate = @MaxModifiedDate;

    IF EXISTS (SELECT 1 FROM DATN_Gold_WH.dbo.water_mark
               WHERE table_name = 'dim_product' AND layer_type = 'gold')
    BEGIN
        UPDATE DATN_Gold_WH.dbo.water_mark
        SET max_modified_date = @NewMaxModifiedDate,
            last_load_time = @CurrentLoadTime,
            row_count = @rows_changed
        WHERE table_name = 'dim_product' AND layer_type = 'gold'
    END
    ELSE
    BEGIN
        INSERT INTO DATN_Gold_WH.dbo.water_mark (table_name, max_modified_date, layer_type, last_load_time, row_count)
        VALUES ('dim_product', @NewMaxModifiedDate, 'gold', @CurrentLoadTime, @rows_changed)
    END

    DROP TABLE #dim_product_stg;

END;
GO

-- EXEC dbo.sp_iload_dim_product