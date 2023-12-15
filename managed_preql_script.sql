BEGIN
USE ROLE ACCOUNTADMIN;

SET company_name = 'company_name'; -- No spaces, just underscores
SET company_uuid = 'fdbb3c0c_5cfe-41d0_8010_374e4566ab6e';

-- Set a password for the Preql user in your Snowflake
SET user_password = 'Test1234!';


-- Please don't change anything below this line
-------------------------------------------------------------------
-- Cleans and capitalizes the company variables
SET company_uuid = (select upper(regexp_replace($company_uuid,'-','_')));
SET company_name = (select upper($company_name));


-- Designates a name for your Preql Warehouse, Database, and User 
SET warehouse_name = 'MANAGED_WH';
SET preql_database_name = 'MANAGED_PREQL_' || upper($company_name) || '_' || upper($company_uuid);
SET raw_database_name = 'MANAGED_RAW_' || upper($company_name) || '_' || upper($company_uuid); 
SET user_name = 'MANAGED_' || upper($company_name);


-- This designates a role and user for Preql Managed User to operate under:
SET role_name = 'MANAGED_PREQL_' || upper($company_name) || '_' || upper($company_uuid);

-- Creates role for Preql Managed User
CREATE ROLE IF NOT EXISTS IDENTIFIER ($role_name);
GRANT ROLE IDENTIFIER ($role_name) TO ROLE sysadmin;

-- Creates a user for Preql and applies role
CREATE USER IF NOT EXISTS IDENTIFIER ($user_name) PASSWORD = $user_password DEFAULT_ROLE = $role_name DEFAULT_WAREHOUSE = $warehouse_name;
GRANT ROLE IDENTIFIER ($role_name) TO USER IDENTIFIER ($user_name);

-- Create databases for Preql and Raw
CREATE OR REPLACE DATABASE IDENTIFIER ($preql_database_name);
CREATE OR REPLACE DATABASE IDENTIFIER ($raw_database_name);

-- Grants Preql role access to the managed warehouse
GRANT USAGE ON WAREHOUSE IDENTIFIER ($warehouse_name) TO ROLE IDENTIFIER ($role_name);

-- Grants Preql Role ownership of Preql databases and underlying schema 
GRANT OWNERSHIP ON DATABASE IDENTIFIER ($preql_database_name) TO ROLE IDENTIFIER ($role_name) REVOKE CURRENT GRANTS;
GRANT USAGE ON DATABASE IDENTIFIER ($preql_database_name) TO ROLE IDENTIFIER ($role_name);
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE IDENTIFIER ($preql_database_name) TO ROLE IDENTIFIER ($role_name) REVOKE CURRENT GRANTS;

GRANT OWNERSHIP ON DATABASE IDENTIFIER ($raw_database_name) TO ROLE IDENTIFIER ($role_name) REVOKE CURRENT GRANTS;
GRANT USAGE ON DATABASE IDENTIFIER ($raw_database_name) TO ROLE IDENTIFIER ($role_name);
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE IDENTIFIER ($raw_database_name) TO ROLE IDENTIFIER ($role_name) REVOKE CURRENT GRANTS;

-- Grants Preql Role all privileges within the Preql Databases for current and future tables
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE IDENTIFIER ($preql_database_name) TO ROLE IDENTIFIER ($role_name);
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE IDENTIFIER ($preql_database_name) TO ROLE IDENTIFIER ($role_name);

GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE IDENTIFIER ($preql_database_name) TO ROLE IDENTIFIER ($role_name);
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE IDENTIFIER ($preql_database_name) TO ROLE IDENTIFIER ($role_name);

USE ROLE ACCOUNTADMIN; -- Need this for future tables and schemas within the RAW DB
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE IDENTIFIER ($raw_database_name) TO ROLE IDENTIFIER ($role_name);
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE IDENTIFIER ($raw_database_name) TO ROLE IDENTIFIER ($role_name);

GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE IDENTIFIER ($raw_database_name) TO ROLE IDENTIFIER ($role_name);
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE IDENTIFIER ($raw_database_name) TO ROLE IDENTIFIER ($role_name);

ALTER USER IDENTIFIER ($user_name) SET DEFAULT_ROLE = $role_name;
ALTER USER IDENTIFIER ($user_name) SET DEFAULT_WAREHOUSE = $warehouse_name;
ALTER USER IDENTIFIER ($user_name) SET DEFAULT_NAMESPACE = $preql_database_name;



USE ROLE IDENTIFIER ($role_name);
USE DATABASE IDENTIFIER ($preql_database_name);
create TABLE IF NOT EXISTS PUBLIC.PREQL_SAMPLE_DATA_CUSTOMERS (CUSTOMER_ID NUMBER(38,0) autoincrement);
END;
