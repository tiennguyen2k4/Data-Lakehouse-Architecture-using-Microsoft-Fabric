USE DATN_Gold_WH
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_date
AS
BEGIN
	SET NOCOUNT ON;

	-- kiểm tra xem bảng dbo.dim_date đã có hay chưa. Nếu có thì xóa bảng này để tạo lại
	DROP TABLE IF EXISTS dbo.dim_date;
	-- tạo bảng dbo.dim_date
    CREATE TABLE dbo.dim_date (
        date_key INT NOT NULL,
        date DATE,
        day INT,
        day_of_week INT,
        day_of_week_name VARCHAR(10),
        day_of_week_short_name VARCHAR(3),
        day_of_week_first_letter VARCHAR(1),
        day_of_year INT,

        iso_week INT,
        iso_year INT,
        iso_year_week VARCHAR(10),

        month INT,
        month_name VARCHAR(10),
        month_short_name VARCHAR(3),

        quarter INT,
        quarter_name VARCHAR(10),

        year INT,
        year_month VARCHAR(10),
        year_quarter VARCHAR(10),

        first_date_of_month DATE,
        last_date_of_month DATE,
        first_date_of_quarter DATE,
        last_date_of_quarter DATE,
        first_date_of_year DATE,
        last_date_of_year DATE,

        nb_days_of_month INT,
        is_leap_year BIT
    );
    ALTER TABLE dbo.dim_date ADD CONSTRAINT pk__dim_date PRIMARY KEY NONCLUSTERED (date_key) NOT ENFORCED;
    ALTER TABLE dbo.dim_date ADD CONSTRAINT u__dim_date UNIQUE NONCLUSTERED ([date]) NOT ENFORCED;
END

-- exec dbo.sp_init_dim_date