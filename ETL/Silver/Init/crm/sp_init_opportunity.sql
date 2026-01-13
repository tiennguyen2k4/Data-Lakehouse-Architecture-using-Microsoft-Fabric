USE DATN_Silver_WH
GO

CREATE OR ALTER PROCEDURE crm.sp_init_opportunity AS

DROP TABLE IF EXISTS DATN_Silver_WH.crm.opportunity

CREATE TABLE DATN_Silver_WH.crm.opportunity (
    opportunity_key INT,
    opportunity_id VARCHAR(10),
    customer_id INT,
    opportunity_stage VARCHAR(255),
    estimated_value DECIMAL(18,2),
    close_date DATETIME2(0),
    row_hash VARCHAR(64),
    modified_date DATETIME2(0)
)
GO

-- EXEC crm.sp_init_opportunity