# streamlit_app.py
import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd # Used for displaying data

# Get the current Snowpark session. This automatically connects to Snowflake.
session = get_active_session()

st.set_page_config(layout="wide")

# --- Custom CSS for Styling ---
# This block injects custom CSS to improve the app's appearance.
# Selectors have been updated to be more robust against Streamlit updates.
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

    /* Customizing Streamlit's alert boxes using data-testid for stability */
    div[data-testid="stAlert"] {
        border-radius: 10px;
        border-width: 2px !important; /* Use !important to override default styles */
        border-style: solid !important;
    }

    /* Success box (green) */
    div[data-testid="stAlert"][data-baseweb="notification-positive"] {
        border-color: #2E7D32 !important;
        background-color: #E8F5E9;
        color: #2E7D32;
    }

    /* Info box (blue) */
    div[data-testid="stAlert"][data-baseweb="notification-info"] {
        border-color: #1976D2 !important;
        background-color: #E3F2FD;
        color: #1976D2;
    }

    /* Warning box (orange) */
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
st.markdown("This section uses Snowflake's built-in context functions, running entirely within Snowflake.")

# Using Snowflake context functions to retrieve real-time session information
try:
    current_role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]
    current_user = session.sql("SELECT CURRENT_USER()").collect()[0][0]
    current_account = session.sql("SELECT CURRENT_ACCOUNT()").collect()[0][0]
    current_region = session.sql("SELECT CURRENT_REGION()").collect()[0][0]

    st.success(f"**Logged in as User:** `{current_user}`")
    st.success(f"**Streamlit App's Primary Role:** `{current_role}`")
    st.info(f"**Snowflake Account:** `{current_account}` in Region `{current_region}`")

    # --- New Diagnostic Section ---
    # Check which of the demo's business roles are active in the session's hierarchy
    st.subheader("Active Business Roles in Session")
    demo_roles = ['ADMIN_ROLE', 'SALES_EAST_ROLE', 'SALES_WEST_ROLE']
    active_demo_roles = []
    for r in demo_roles:
        # IS_ROLE_IN_SESSION checks the hierarchy of the current primary role
        is_active = session.sql(f"SELECT IS_ROLE_IN_SESSION('{r}')").collect()[0][0]
        if is_active:
            active_demo_roles.append(r)
    
    if active_demo_roles:
        st.info(f"The app's primary role has the following business roles granted to it: **{', '.join(active_demo_roles)}**. The view uses this to filter data.")
    else:
        st.warning("None of the demo's business roles (ADMIN_ROLE, SALES_EAST_ROLE, SALES_WEST_ROLE) are active in this session's hierarchy.")


except Exception as e:
    st.error(f"Could not retrieve session context: {e}")

st.markdown("---")

# --- Section 2: Display Sales Data (Filtered by Role) ---
st.header("Sales Data Overview (Role-Filtered)")
st.warning("""
    The sales data shown below is dynamically filtered based on the business roles active in the app's session (e.g., `ADMIN_ROLE`, `SALES_EAST_ROLE`).
    This is achieved using a secure VIEW with `IS_ROLE_IN_SESSION()` logic, which is more robust than checking only the primary role.
""")

try:
    # Corrected the path to the view to match the development setup.
    sales_df = session.table("STREAMLIT_DEMO_DB.DEMO_SCHEMA.FILTERED_SALES_VIEW").to_pandas()

    if not sales_df.empty:
        st.subheader(f"Sales Records Visible to Session with Roles: {', '.join(active_demo_roles)}")
        st.dataframe(sales_df, use_container_width=True)
        st.success(f"Displaying {len(sales_df)} record(s).")
    else:
        st.info(f"No sales data visible for the active roles in your session (`{', '.join(active_demo_roles)}`), or no data exists.")

except Exception as e:
    st.error(f"Error fetching filtered sales data from Snowflake: {e}")
    st.info("Please ensure the `SALES_DATA` table and `FILTERED_SALES_VIEW` view are set up correctly with appropriate grants in the `STREAMLIT_DEMO_DB.DEMO_SCHEMA`.")

st.markdown("---")
st.info("""
    **Demo Tip:**
    To see the effect of role-based filtering, you can grant and revoke the business roles (`SALES_EAST_ROLE`, `ADMIN_ROLE`, etc.) from the Streamlit app's owner role and then refresh the app.
""")
