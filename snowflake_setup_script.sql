BEGIN;

-- Change this to false if you want to only give Preql access to specific databases. Preql will only have USAGE and SELECT privileges on these databases
set grant_access_to_all_dbs = True; 


-- If you aren't granting access to all DBs above, list DBs that contain Fivetran data, source data, and/or first party data you intend to use Preql with (comma separated):
SET dbs = 'TEST,TEST2';

-- Set a password for the Preql user in your Snowflake
SET user_password = 'Test1234!';

-- Designate a name for your Preql Warehouse, Database, and User (or leave these defaults)
SET warehouse_name = 'PREQL_WAREHOUSE';
SET database_name = 'PREQL_DATABASE';
SET user_name = 'PREQL_USER';


-- Please don't change anything below this line
-------------------------------------------------------------------
-- This designates a role and user for Preql to operate under:
SET role_name = 'PREQL_ROLE';


-- Changes role to securityadmin for user/role steps
USE ROLE securityadmin;

-- Creates role for Preql
CREATE ROLE IF NOT EXISTS IDENTIFIER ($role_name);
GRANT ROLE IDENTIFIER ($role_name) TO ROLE sysadmin;

-- Creates a user for Preql and applies role
CREATE USER IF NOT EXISTS IDENTIFIER ($user_name) PASSWORD = $user_password DEFAULT_ROLE = $role_name DEFAULT_WAREHOUSE = $warehouse_name;
GRANT ROLE IDENTIFIER ($role_name) TO USER IDENTIFIER ($user_name);

-- Changes role to sysadmin for warehouse/database steps
USE ROLE sysadmin;

-- Creates a warehouse for Preql
CREATE OR REPLACE WAREHOUSE IDENTIFIER ($warehouse_name)
   AUTO_SUSPEND = 60
   AUTO_RESUME = TRUE
   INITIALLY_SUSPENDED = TRUE;

-- Creates database for Preql
CREATE OR REPLACE DATABASE  IDENTIFIER ($database_name);

-- Grants Preql role access to the Preql warehouse
GRANT USAGE ON WAREHOUSE IDENTIFIER ($warehouse_name) TO ROLE IDENTIFIER ($role_name);

-- Grants Preql Role ownership of Preql database and underlying schema -> The Preql role has been granted to SYSADMIN so you will still have control of this space when needed
GRANT OWNERSHIP ON DATABASE IDENTIFIER ($database_name) TO ROLE IDENTIFIER ($role_name) REVOKE CURRENT GRANTS;
GRANT USAGE ON DATABASE IDENTIFIER ($database_name) TO ROLE IDENTIFIER ($role_name);
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE IDENTIFIER ($database_name) TO ROLE IDENTIFIER ($role_name) REVOKE CURRENT GRANTS;

-- Grants Preql Role all privileges within the Preql Database for current and future tables
USE ROLE ACCOUNTADMIN; -- Need this for future tables and schemas within the PREQL DB
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE IDENTIFIER ($database_name) TO ROLE IDENTIFIER ($role_name);
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE IDENTIFIER ($database_name) TO ROLE IDENTIFIER ($role_name);

GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE IDENTIFIER ($database_name) TO ROLE IDENTIFIER ($role_name);
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE IDENTIFIER ($database_name) TO ROLE IDENTIFIER ($role_name);


-- Setup a dummy table that sample data onboarding can reference 
USE ROLE IDENTIFIER($role_name);
USE DATABASE IDENTIFIER($database_name);
create TABLE IF NOT EXISTS PUBLIC.PREQL_SAMPLE_DATA_CUSTOMERS (CUSTOMER_ID NUMBER(38,0) autoincrement);

USE ROLE ACCOUNTADMIN;
-- Grant Preql access to Snowflake tables for Usage and Consumption models within the Preql product
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE IDENTIFIER ($role_name);
USE DATABASE SNOWFLAKE;
USE SCHEMA ACCOUNT_USAGE;
GRANT DATABASE ROLE OBJECT_VIEWER TO ROLE IDENTIFIER ($role_name);
GRANT DATABASE ROLE USAGE_VIEWER TO ROLE IDENTIFIER ($role_name);

-- This block grants access to non-Preql databases to grab the data to model. Only USAGE and SELECT are granted. This access includes current and future tables and schema. The databases included depend on the flag set at the beginning, either all databases available (that are not from a shared source) or a predefined list, per the customer's decision.
BEGIN 
IF ($grant_access_to_all_dbs = TRUE) THEN
show shares;
DECLARE
db_cursor CURSOR FOR select database_name from information_schema.databases d where database_name not in (select "database_name" from table(result_scan(last_query_id()))); -- This query excludes databases that are shared or imported
BEGIN
OPEN db_cursor;
FOR db in db_cursor DO
    execute immediate 'GRANT USAGE ON DATABASE ' || db.database_name || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT USAGE ON ALL SCHEMAS IN DATABASE ' || db.database_name || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT USAGE ON FUTURE SCHEMAS IN DATABASE ' || db.database_name || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT SELECT ON ALL TABLES IN DATABASE ' || db.database_name || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT SELECT ON FUTURE TABLES IN DATABASE ' || db.database_name || ' to ROLE ' || $role_name || ';';
END FOR;
CLOSE db_cursor;
END;

ELSE -- Loop through list of DBs and give the Preql Role access to current and future tables for the list provided
DECLARE
db_cursor CURSOR FOR select value from table(split_to_table($dbs,','));
BEGIN
OPEN db_cursor;
FOR db in db_cursor DO
    execute immediate 'GRANT USAGE ON DATABASE ' || db.value || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT USAGE ON ALL SCHEMAS IN DATABASE ' || db.value || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT USAGE ON FUTURE SCHEMAS IN DATABASE ' || db.value || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT SELECT ON ALL TABLES IN DATABASE ' || db.value || ' to ROLE ' || $role_name || ';';
    execute immediate 'GRANT SELECT ON FUTURE TABLES IN DATABASE ' || db.value || ' to ROLE ' || $role_name || ';';
END FOR;
CLOSE db_cursor;
END;
END IF;


END;
