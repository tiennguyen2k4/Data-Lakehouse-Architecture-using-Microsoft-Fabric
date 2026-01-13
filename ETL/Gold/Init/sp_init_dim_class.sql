USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_class AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.dim_class

CREATE TABLE DATN_Gold_WH.dbo.dim_class (
    class_key INT NOT NULL,
	parent_class_id INT,
	class_code VARCHAR(50),
	class_name VARCHAR(500),
    class_level INT,
    sort_order INT,
	is_debit_normal BIT,
	modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_dim_class