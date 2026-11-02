#!/bin/bash
set -euo pipefail

# Executado apenas na criação de um volume vazio; não contém migrations de aplicações.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<'SQL'
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;
REVOKE CONNECT ON DATABASE template1 FROM PUBLIC;
SQL

for service in users catalog payments notifications; do
    variable="${service^^}_DB_PASSWORD"
    password="${!variable:?Senha do serviço ausente}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
        --set=role="fcg_${service}" --set=db="fcg_${service}" --set=password="$password" <<'SQL'
CREATE ROLE :"role" LOGIN PASSWORD :'password' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE DATABASE :"db" OWNER :"role";
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db" TO :"role";
SQL
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "fcg_${service}" <<'SQL'
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL
done
