# Snowflake & Streamlit: Role-Based Sales Dashboard Demo

This repository contains the code and setup instructions for a demonstration project showcasing how to build a secure, role-based dashboard using Streamlit in Snowflake (SiS). The application displays sales data that is dynamically filtered based on the Snowflake role of the user viewing the app.

## Key Concepts Demonstrated
* **Streamlit in Snowflake (SiS):** Building and deploying a Python web application directly within the Snowflake ecosystem.
* **Dynamic Row-Level Security:** Using a secure `VIEW` in conjunction with Snowflake's `IS_ROLE_IN_SESSION()` context function to filter data dynamically and securely at query time.
* **Role-Based Access Control (RBAC):** Creating and managing specific business roles (`ADMIN_ROLE`, `SALES_EAST_ROLE`, `SALES_WEST_ROLE`) to control data visibility.
* **Custom CSS Styling:** Injecting custom CSS to enhance the visual design and user experience of a Streamlit application.

## How It Works
The core of the security model is the `FILTERED_SALES_VIEW`. Instead of the Streamlit app querying the base `SALES_DATA` table directly, it queries this view.

The view's `WHERE` clause uses the `IS_ROLE_IN_SESSION()` function to check which of the defined business roles are active in the current user's session hierarchy.
* An `ADMIN_ROLE` sees all data.
* A `SALES_EAST_ROLE` sees only data where the `REGION` is 'East'.
* A `SALES_WEST_ROLE` sees only data where the `REGION` is 'West'.

This ensures that the data filtering logic is enforced within Snowflake, providing a robust and secure way to manage data access without exposing sensitive logic in the front-end application code.

## Setup & Usage

### Prerequisites
* A Snowflake account.
* A user with privileges to create databases, schemas, tables, views, and roles (e.g., `ACCOUNTADMIN`).
* A virtual warehouse to run the Streamlit app's queries.

### Step 1: Run the SQL Setup Script
Execute the following SQL script in a Snowflake worksheet. This will create the necessary database, schema, roles, sample data table, and the secure view.

**Remember to replace `COMPUTE_WH` with your warehouse and `CCHAFFINS` with your test user's login name.**

```sql
-- =========================================================
-- SQL SETUP FOR STREAMLIT ROLE-BASED DASHBOARD DEMO
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
GRANT USAGE ON DATABASE STREAMLIT_DEMO_DB TO ROLE SALES_EAST_ROLE;
GRANT USAGE ON DATABASE STREAMLIT_DEMO_DB TO ROLE SALES_WEST_ROLE;
GRANT USAGE ON DATABASE STREAMLIT_DEMO_DB TO ROLE ADMIN_ROLE;
GRANT USAGE ON SCHEMA DEMO_SCHEMA TO ROLE SALES_EAST_ROLE;
GRANT USAGE ON SCHEMA DEMO_SCHEMA TO ROLE SALES_WEST_ROLE;
GRANT USAGE ON SCHEMA DEMO_SCHEMA TO ROLE ADMIN_ROLE;
GRANT SELECT ON TABLE SALES_DATA TO ROLE SALES_EAST_ROLE;
GRANT SELECT ON TABLE SALES_DATA TO ROLE SALES_WEST_ROLE;
GRANT SELECT ON TABLE SALES_DATA TO ROLE ADMIN_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SALES_EAST_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SALES_WEST_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ADMIN_ROLE;

-- 5. Create the secure view
CREATE OR REPLACE VIEW FILTERED_SALES_VIEW AS
SELECT SALE_ID, PRODUCT_CATEGORY, REGION, SALES_AMOUNT
FROM SALES_DATA
WHERE
    IS_ROLE_IN_SESSION('ADMIN_ROLE')
    OR (IS_ROLE_IN_SESSION('SALES_EAST_ROLE') AND REGION = 'East')
    OR (IS_ROLE_IN_SESSION('SALES_WEST_ROLE') AND REGION = 'West');

-- 6. Grant SELECT on the view to the roles
GRANT SELECT ON VIEW FILTERED_SALES_VIEW TO ROLE SALES_EAST_ROLE;
GRANT SELECT ON VIEW FILTERED_SALES_VIEW TO ROLE SALES_WEST_ROLE;
GRANT SELECT ON VIEW FILTERED_SALES_VIEW TO ROLE ADMIN_ROLE;

-- 7. Grant roles to your user and to a higher-level role
GRANT ROLE SALES_EAST_ROLE TO USER CCHAFFINS;
GRANT ROLE SALES_WEST_ROLE TO USER CCHAFFINS;
GRANT ROLE ADMIN_ROLE TO USER CCHAFFINS;
GRANT ROLE ADMIN_ROLE TO ROLE ACCOUNTADMIN;
GRANT ROLE SALES_EAST_ROLE TO ROLE ACCOUNTADMIN;
GRANT ROLE SALES_WEST_ROLE TO ROLE ACCOUNTADMIN;

-- 8. Grant Streamlit creation privileges
GRANT CREATE STREAMLIT ON SCHEMA STREAMLIT_DEMO_DB.DEMO_SCHEMA TO ROLE ADMIN_ROLE;
GRANT CREATE STAGE ON SCHEMA STREAMLIT_DEMO_DB.DEMO_SCHEMA TO ROLE ADMIN_ROLE;
```

### Step 2: Create the Streamlit App in Snowflake
1.  Navigate to the **Streamlit** section in the Snowflake UI (Snowsight).
2.  Click **+ Streamlit App**.
3.  Name your application (e.g., `Role Based Sales Dashboard`).
4.  Place the app in the `STREAMLIT_DEMO_DB` database and `DEMO_SCHEMA` schema.
5.  Select a warehouse for the app to run on.
6.  Click **Create**.
7.  You will be taken to a new Streamlit app with boilerplate code. Replace the contents of the editor with the Python code below.

### Application Code (`streamlit_app.py`)
```python
# streamlit_app.py
import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd # Used for displaying data

# Get the current Snowpark session. This automatically connects to Snowflake.
session = get_active_session()

st.set_page_config(layout="wide")

# --- Custom CSS for Styling ---
st.markdown("""
<style>
    /* Main app container */
    .main .block-container {
        padding-top: 2rem;
        padding-bottom: 2rem;
        padding-left: 5rem;
        padding-right: 5rem;
    }
    /* Page Title */
    h1 {
        color: #0024ff!important;
        font-weight: bold;
    }
    /* Section Headers */
    h2 {
        color: #31333F;
        border-bottom: 2px solid #DCDCDC;
        padding-bottom: 10px;
        margin-top: 2rem;
    }
    h3 {
        color: #31333F;
        margin-top: 2rem;
    }
    /* Customizing Streamlit's alert boxes */
    div[data-testid="stAlert"] {
        border-radius: 10px;
        border-width: 2px !important;
        border-style: solid !important;
    }
    div[data-testid="stAlert"][data-baseweb="notification-positive"] {
        border-color: #2E7D32 !important;
        background-color: #E8F5E9;
        color: #2E7D32;
    }
    div[data-testid="stAlert"][data-baseweb="notification-info"] {
        border-color: #1976D2 !important;
        background-color: #E3F2FD;
        color: #1976D2;
    }
    div[data-testid="stAlert"][data-baseweb="notification-warning"] {
        border-color: #ED6C02 !important;
        background-color: #FFF4E5;
        color: #ED6C02;
    }
</style>
""", unsafe_allow_html=True)


st.title("Dynamic Sales Data Dashboard")
st.markdown("---")

# --- Section 1: Display Current User Context ---
st.header("Your Current Snowflake Session Context")

try:
    current_role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]
    current_user = session.sql("SELECT CURRENT_USER()").collect()[0][0]
    current_account = session.sql("SELECT CURRENT_ACCOUNT()").collect()[0][0]
    current_region = session.sql("SELECT CURRENT_REGION()").collect()[0][0]

    st.success(f"**Logged in as User:** `{current_user}`")
    st.success(f"**Streamlit App's Primary Role:** `{current_role}`")
    st.info(f"**Snowflake Account:** `{current_account}` in Region `{current_region}`")

    st.subheader("Active Business Roles in Session")
    demo_roles = ['ADMIN_ROLE', 'SALES_EAST_ROLE', 'SALES_WEST_ROLE']
    active_demo_roles = []
    for r in demo_roles:
        is_active = session.sql(f"SELECT IS_ROLE_IN_SESSION('{r}')").collect()[0][0]
        if is_active:
            active_demo_roles.append(r)
    
    if active_demo_roles:
        st.info(f"The app's primary role has the following business roles granted to it: **{', '.join(active_demo_roles)}**.")
    else:
        st.warning("None of the demo's business roles are active in this session's hierarchy.")

except Exception as e:
    st.error(f"Could not retrieve session context: {e}")

st.markdown("---")

# --- Section 2: Display Sales Data (Filtered by Role) ---
st.header("Sales Data Overview (Role-Filtered)")
st.warning("The data below is dynamically filtered by the secure VIEW based on your session's active roles.")

try:
    sales_df = session.table("STREAMLIT_DEMO_DB.DEMO_SCHEMA.FILTERED_SALES_VIEW").to_pandas()

    if not sales_df.empty:
        st.subheader(f"Sales Records Visible to Session")
        st.dataframe(sales_df, use_container_width=True)
        st.success(f"Displaying {len(sales_df)} record(s).")
    else:
        st.info(f"No sales data visible for the active roles in your session.")

except Exception as e:
    st.error(f"Error fetching filtered sales data: {e}")

st.markdown("---")
st.info("To test the filtering, grant/revoke the business roles from the Streamlit app's owner role and refresh.")
```

### Step 3: Test the Role-Based Access
1.  Run the app. The "owner" of the Streamlit app is typically a high-level role (like `ACCOUNTADMIN` if you ran the script as-is). Since `ACCOUNTADMIN` was granted all three business roles, it should see all 8 records.
2.  To test the filtering, you can change the owner of the Streamlit App to a different role or grant/revoke the business roles (`SALES_EAST_ROLE`, `ADMIN_ROLE`, etc.) from the owner role and refresh the app to see the data change.
