#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- S'assurer que l'utilisateur admin existe et a les bonnes permissions
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'admin') THEN
            CREATE USER admin WITH PASSWORD 'admin' SUPERUSER CREATEDB;
        ELSE
            ALTER USER admin WITH PASSWORD 'admin' SUPERUSER CREATEDB;
        END IF;
    END
    \$\$;
    
    -- Donner tous les privilèges à admin
    GRANT ALL PRIVILEGES ON DATABASE crypto TO admin;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO admin;
EOSQL

