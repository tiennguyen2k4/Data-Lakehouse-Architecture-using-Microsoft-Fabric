USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_fact_survey AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.fact_survey

CREATE TABLE DATN_Gold_WH.dbo.fact_survey (
    survey_key INT NOT NULL,
    survey_code VARCHAR(50),
	customer_key INT,
    product_key INT,
    survey_date_key INT,
    overall_rating INT,
    quality_rating INT,
    price_rating INT,
    service_rating INT,
    recommendation VARCHAR(10),
    purchase_channel VARCHAR(25),
	customers_segment VARCHAR(25),
	comments VARCHAR(255),
    modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_fact_survey