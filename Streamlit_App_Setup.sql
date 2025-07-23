-- =========================================================
-- SQL SETUP FOR STREAMLIT ROLE-BASED DASHBOARD DEMO
-- Run these commands in a Snowflake Worksheet with ACCOUNTADMIN or a high-privileged role.
-- =========================================================

-- Create a dedicated database and schema for the demo
CREATE DATABASE IF NOT EXISTS STREAMLIT_DEMO_DB;
CREATE SCHEMA IF NOT EXISTS STREAMLIT_DEMO_DB.DEMO_SCHEMA;
USE DATABASE STREAMLIT_DEMO_DB;
USE SCHEMA DEMO_SCHEMA;

-- 1. Create a dummy sales data table
CREATE OR REPLACE TABLE SALES_DATA (
    SALE_ID INT,
    PRODUCT_CATEGORY VARCHAR,
    REGION VARCHAR,
    SALES_AMOUNT DECIMAL(10, 2),
    -- This column is for conceptual reference and not used in the final view logic
    EMPLOYEE_ROLE VARCHAR
);

-- 2. Insert sample sales data
INSERT INTO SALES_DATA (SALE_ID, PRODUCT_CATEGORY, REGION, SALES_AMOUNT, EMPLOYEE_ROLE) VALUES
(1, 'Electronics', 'East', 1000.00, 'SALES_EAST_ROLE'),
(2, 'Electronics', 'West', 1500.00, 'SALES_WEST_ROLE'),
(3, 'Apparel', 'East', 800.00, 'SALES_EAST_ROLE'),
(4, 'Apparel', 'West', 1200.00, 'SALES_WEST_ROLE'),
(5, 'Home Goods', 'Global', 5000.00, 'ADMIN_ROLE'),
(6, 'Software', 'East', 2500.00, 'SALES_EAST_ROLE'),
(7, 'Software', 'West', 3000.00, 'SALES_WEST_ROLE'),
(8, 'Services', 'Global', 7500.00, 'ADMIN_ROLE');

-- 3. Create specific roles for demonstration
CREATE ROLE IF NOT EXISTS SALES_EAST_ROLE;
CREATE ROLE IF NOT EXISTS SALES_WEST_ROLE;
CREATE ROLE IF NOT EXISTS ADMIN_ROLE;

-- 4. Grant necessary privileges to these roles
-- Grant usage on database
GRANT USAGE ON DATABASE STREAMLIT_DEMO_DB TO ROLE SALES_EAST_ROLE;
GRANT USAGE ON DATABASE STREAMLIT_DEMO_DB TO ROLE SALES_WEST_ROLE;
GRANT USAGE ON DATABASE STREAMLIT_DEMO_DB TO ROLE ADMIN_ROLE;

-- Grant usage on schema
GRANT USAGE ON SCHEMA DEMO_SCHEMA TO ROLE SALES_EAST_ROLE;
GRANT USAGE ON SCHEMA DEMO_SCHEMA TO ROLE SALES_WEST_ROLE;
GRANT USAGE ON SCHEMA DEMO_SCHEMA TO ROLE ADMIN_ROLE;

-- Grant SELECT on the base table
GRANT SELECT ON TABLE SALES_DATA TO ROLE SALES_EAST_ROLE;
GRANT SELECT ON TABLE SALES_DATA TO ROLE SALES_WEST_ROLE;
GRANT SELECT ON TABLE SALES_DATA TO ROLE ADMIN_ROLE;

-- Grant usage on a warehouse (replace COMPUTE_WH with your warehouse)
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SALES_EAST_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SALES_WEST_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ADMIN_ROLE;

-- 5. Create a view that filters data based on roles active in the session
-- This is a more robust approach than checking CURRENT_ROLE()
-- It checks if the required business role is in the current role's hierarchy.
CREATE OR REPLACE VIEW FILTERED_SALES_VIEW AS
SELECT
    SALE_ID,
    PRODUCT_CATEGORY,
    REGION,
    SALES_AMOUNT
FROM
    SALES_DATA
WHERE
    -- Admin role sees all data
    IS_ROLE_IN_SESSION('ADMIN_ROLE')
    -- Sales East role sees only data for the 'East' region
    OR (IS_ROLE_IN_SESSION('SALES_EAST_ROLE') AND REGION = 'East')
    -- Sales West role sees only data for the 'West' region
    OR (IS_ROLE_IN_SESSION('SALES_WEST_ROLE') AND REGION = 'West')
;

-- 6. Grant SELECT privilege on the *filtered view* to the roles
GRANT SELECT ON VIEW FILTERED_SALES_VIEW TO ROLE SALES_EAST_ROLE;
GRANT SELECT ON VIEW FILTERED_SALES_VIEW TO ROLE SALES_WEST_ROLE;
GRANT SELECT ON VIEW FILTERED_SALES_VIEW TO ROLE ADMIN_ROLE;

-- 7. Grant these roles to your test user(s) and to ACCOUNTADMIN
-- This allows ACCOUNTADMIN (often the Streamlit app owner) to inherit the permissions.
GRANT ROLE SALES_EAST_ROLE TO USER CCHAFFINS;
GRANT ROLE SALES_WEST_ROLE TO USER CCHAFFINS;
GRANT ROLE ADMIN_ROLE TO USER CCHAFFINS;

-- Granting the business roles to a higher-level role is a common pattern
GRANT ROLE ADMIN_ROLE TO ROLE ACCOUNTADMIN;
GRANT ROLE SALES_EAST_ROLE TO ROLE ACCOUNTADMIN;
GRANT ROLE SALES_WEST_ROLE TO ROLE ACCOUNTADMIN;

-- =========================================================
-- SQL SETUP COMPLETE
-- =========================================================



-- =========================================================
-- SQL to Grant Streamlit Creation Privileges to a Role
--
-- Run these commands with a high-privileged role like ACCOUNTADMIN.
-- This will allow users with the 'ADMIN_ROLE' to create and run
-- Streamlit apps in the specified schema.
-- =========================================================

-- 1. Grant USAGE on the database and schema.
-- This allows the role to "see" and use the containers.
GRANT USAGE ON DATABASE STREAMLIT_DEMO_DB TO ROLE ADMIN_ROLE;
GRANT USAGE ON SCHEMA STREAMLIT_DEMO_DB.DEMO_SCHEMA TO ROLE ADMIN_ROLE;

-- 2. Grant USAGE on a virtual warehouse.
-- Streamlit apps need a warehouse to run their queries.
-- Replace 'COMPUTE_WH' with the name of a warehouse the role should use.
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ADMIN_ROLE;

-- 3. Grant schema-level privileges for app creation.
-- CREATE STREAMLIT allows creating the app object itself.
-- CREATE STAGE is required to upload the Streamlit application files.
GRANT CREATE STREAMLIT ON SCHEMA STREAMLIT_DEMO_DB.DEMO_SCHEMA TO ROLE ADMIN_ROLE;
GRANT CREATE STAGE ON SCHEMA STREAMLIT_DEMO_DB.DEMO_SCHEMA TO ROLE ADMIN_ROLE;

-- =========================================================
-- Grant the Role to a User
-- =========================================================

-- Finally, ensure the user who will be creating the app has the ADMIN_ROLE.
-- Replace 'YOUR_USER_NAME' with the actual user's login name.
GRANT ROLE ADMIN_ROLE TO USER CCHAFFINS;

-- =========================================================
-- Grants Complete
-- =========================================================
