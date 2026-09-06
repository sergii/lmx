#!/usr/bin/env bash
set -euo pipefail

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"

# The official postgres entrypoint runs this only while initializing an empty
# PGDATA directory. lmx_primary is created through POSTGRES_DB; create the
# remaining Rails databases with the same schema-owner role.
for database in lmx_cache lmx_queue lmx_cable; do
  echo "Creating ${database} owned by ${POSTGRES_USER}"
  createdb \
    --username "${POSTGRES_USER}" \
    --owner "${POSTGRES_USER}" \
    "${database}"
done
