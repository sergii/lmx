-- lmx_primary is created by POSTGRES_DB. The remaining Rails databases share
-- the same schema-owner role and are initialized only when PGDATA is empty.
CREATE DATABASE lmx_cache OWNER lmx_owner;
CREATE DATABASE lmx_queue OWNER lmx_owner;
CREATE DATABASE lmx_cable OWNER lmx_owner;
