USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_water_mark AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.water_mark

CREATE TABLE DATN_Gold_WH.dbo.water_mark (
    table_name VARCHAR(50),
    max_modified_date DATETIME2(0),
    layer_type VARCHAR(50),
    last_load_time DATETIME2(0),
    row_count INT
)
GO

-- EXEC dbo.sp_init_water_mark

