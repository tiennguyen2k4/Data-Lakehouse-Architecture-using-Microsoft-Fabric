USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE erp.sp_init_class AS

DROP TABLE IF EXISTS DATN_Silver_WH.erp.[class]

CREATE TABLE DATN_Silver_WH.erp.[class] (
    class_id INT NOT NULL,
    parent_class_id INT,
	class_code VARCHAR(50),
	class_name VARCHAR(500),
    class_level INT,
    sort_order INT,
	is_debit_normal BIT,
	modified_date DATETIME2(0)
)
GO

-- EXEC erp.sp_init_class