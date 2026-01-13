USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_survey AS

DROP TABLE IF EXISTS DATN_Silver_WH.dbo.survey

CREATE TABLE DATN_Silver_WH.dbo.survey (
    survey_id INT NOT NULL,
    survey_code VARCHAR(50),
	customer_id INT,
    product_id INT,
    survey_date DATETIME2(0),
    overall_rating INT,
    quality_rating INT,
    price_rating INT,
    service_rating INT,
    recommendation VARCHAR(10),
    purchase_channel VARCHAR(25),
	customers_segment VARCHAR(25),
	comments VARCHAR(255),
    row_hash VARCHAR(64),
    modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_survey