USE DATN_Gold_WH
GO

CREATE OR ALTER PROCEDURE dbo.sp_init_dim_opportunity AS

DROP TABLE IF EXISTS DATN_Gold_WH.dbo.fact_opportunity

CREATE TABLE DATN_Gold_WH.dbo.fact_opportunity (
    opportunity_key INT,
    opportunity_id VARCHAR(10),
    customer_key INT,
    opportunity_stage VARCHAR(255),
    estimated_value DECIMAL(18,2),
    close_date_key INT,
    modified_date DATETIME2(0)
)
GO

-- EXEC dbo.sp_init_fact_opportunity