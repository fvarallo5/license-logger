#!/usr/bin/env bash
# Proves the migrations + seed apply cleanly and runs the pgTAP suite on a PLAIN Postgres 17
# (no Docker). Uses scripts/local_stub/00_supabase_stub.sql to imitate the auth/vault
# pieces Supabase provides. Prefer `supabase start && supabase test db` when Docker is available.
#
#   PGHOST=/tmp PGPORT=5432 PGUSER=postgres ./scripts/test-local-no-docker.sh
set -euo pipefail
cd "$(dirname "$0")/../supabase"
DB=${LL_TEST_DB:-ll_test}
P="psql -v ON_ERROR_STOP=1 -q"
$P -d postgres -c "drop database if exists $DB" -c "create database $DB"
$P -d "$DB" -f ../scripts/local_stub/00_supabase_stub.sql
for f in migrations/*.sql; do echo "apply $f"; $P -d "$DB" -1 -f "$f"; done
echo "seed"; $P -d "$DB" -1 -f seed.sql >/dev/null
(cd tests/database && pg_prove -d "$DB" *.test.sql)
