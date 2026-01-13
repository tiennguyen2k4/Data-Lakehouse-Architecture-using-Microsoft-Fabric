USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_product AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_product

CREATE TABLE DATN_Gold_WH.dbo.dim_product (
    product_key INT NOT NULL,
    name VARCHAR(255),
    category VARCHAR(50),
	subcategory VARCHAR(50),
    model VARCHAR(50),
    line VARCHAR(2),
    class VARCHAR(2),
	style VARCHAR(2),
    color VARCHAR(25),
    size VARCHAR(5),
    weight DECIMAL(18,2),
    description VARCHAR(500),
    standard_cost DECIMAL(18,4),
    list_price DECIMAL(18,4),
    make_flag BIT,
    finished_goods_flag BIT,
    safety_stock_level INT,
    reorder_point INT,
    days_to_manufacture INT,
    sell_start_date DATETIME2(0),
    sell_end_date DATETIME2(0),
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_product
