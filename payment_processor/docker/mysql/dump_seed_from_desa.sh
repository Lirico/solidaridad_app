#!/usr/bin/env bash
# Dump schema + filtered seed for the 15 tables used by the legacy C processor.
# Temporal tables: last SEED_MONTHS of activity relative to each table's MAX(ts)
# (desa may be stale vs calendar "now"). Ledger tables also keep the latest row
# per account so balances remain usable.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="${ROOT}/.env"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEED_MONTHS="${SEED_MONTHS:-2}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

: "${DESA_MYSQL_HOST:?Set DESA_MYSQL_HOST in payment_processor/.env}"
: "${DESA_MYSQL_PORT:=3306}"
: "${DESA_MYSQL_USER:?Set DESA_MYSQL_USER in payment_processor/.env}"
: "${DESA_MYSQL_PASSWORD:?Set DESA_MYSQL_PASSWORD in payment_processor/.env}"
: "${DESA_MYSQL_DATABASE:=kigsolidario2}"

MYSQL=(mysql -h "$DESA_MYSQL_HOST" -P "$DESA_MYSQL_PORT" -u "$DESA_MYSQL_USER" -p"$DESA_MYSQL_PASSWORD" --skip-ssl "$DESA_MYSQL_DATABASE")
DUMP=(mysqldump -h "$DESA_MYSQL_HOST" -P "$DESA_MYSQL_PORT" -u "$DESA_MYSQL_USER" -p"$DESA_MYSQL_PASSWORD" --skip-ssl
  --single-transaction --quick --skip-comments --compact
  "$DESA_MYSQL_DATABASE")

TABLES=(
  terminales
  sgas_usuario
  sgas_usuario_cta
  sgas_productos
  sgas_comercio
  sgas_comercio_cta
  sgas_cup
  sgas_trx
  sgas_cup_trx
  iso_pool
  soli_categories
  sgas_usuario_expansion
  soli_config
  sgas_usuario_load
  soli_db_scripts
)

FULL_TABLES=(
  terminales
  sgas_usuario
  sgas_productos
  sgas_comercio
  soli_categories
  sgas_usuario_expansion
  soli_config
  sgas_usuario_load
  soli_db_scripts
)

echo "==> Schema → ${OUT_DIR}/01_schema.sql"
"${DUMP[@]}" --no-data "${TABLES[@]}" | sed '/enable the sandbox mode/d' > "${OUT_DIR}/01_schema.sql"

SEED_SQL="${OUT_DIR}/02_seed.sql"
rm -f "$SEED_SQL" "${OUT_DIR}/02_seed.sql.gz"
{
  echo "-- Seed generated $(date -u +%Y-%m-%dT%H:%M:%SZ) from ${DESA_MYSQL_HOST}/${DESA_MYSQL_DATABASE}"
  echo "-- Temporal window: last ${SEED_MONTHS} months of activity per table (relative to MAX(ts))"
  echo "SET NAMES utf8;"
  echo "SET FOREIGN_KEY_CHECKS=0;"
} > "$SEED_SQL"

dump_full() {
  local t=$1
  echo "==> Full data: $t"
  "${DUMP[@]}" --no-create-info --complete-insert "$t" | sed '/enable the sandbox mode/d' >> "$SEED_SQL"
}

# Cutoff = DATE_SUB(MAX(col), INTERVAL N MONTH); if MAX is NULL, skip data.
table_cutoff() {
  local table=$1 col=$2
  "${MYSQL[@]}" -N -e "SELECT IFNULL(DATE_FORMAT(DATE_SUB(MAX(\`${col}\`), INTERVAL ${SEED_MONTHS} MONTH), '%Y-%m-%d %H:%i:%s'), '') FROM \`${table}\`;"
}

dump_where() {
  local t=$1 where=$2
  echo "==> Filtered data: $t  WHERE $where"
  "${DUMP[@]}" --no-create-info --complete-insert --where="$where" "$t" | sed '/enable the sandbox mode/d' >> "$SEED_SQL"
}

for t in "${FULL_TABLES[@]}"; do
  dump_full "$t"
done

# --- temporal / ledger ---
trx_cut=$(table_cutoff sgas_trx ts_operacion)
if [[ -n "$trx_cut" ]]; then
  dump_where sgas_trx "ts_operacion >= '${trx_cut}'"
fi

iso_cut=$(table_cutoff iso_pool datetime_trx)
if [[ -n "$iso_cut" ]]; then
  dump_where iso_pool "datetime_trx >= '${iso_cut}'"
fi

cup_cut=$(table_cutoff sgas_cup ts_operacion)
if [[ -n "$cup_cut" ]]; then
  dump_where sgas_cup "ts_operacion >= '${cup_cut}'"
fi

cup_trx_cut=$(table_cutoff sgas_cup_trx ts_operacion)
if [[ -n "$cup_trx_cut" ]]; then
  dump_where sgas_cup_trx "ts_operacion >= '${cup_trx_cut}'"
fi

# usuario_cta: window + latest row per (nro_tarjeta, prod_id)
ucta_cut=$(table_cutoff sgas_usuario_cta ts_operacion)
if [[ -n "$ucta_cut" ]]; then
  dump_where sgas_usuario_cta \
    "ts_operacion >= '${ucta_cut}' OR id_tr IN (SELECT id_tr FROM (SELECT MAX(id_tr) AS id_tr FROM sgas_usuario_cta GROUP BY nro_tarjeta, prod_id) x)"
fi

# comercio_cta: window + latest row per (cod_comercio, prod_id, nro_sucursal)
ccta_cut=$(table_cutoff sgas_comercio_cta ts_operacion)
if [[ -n "$ccta_cut" ]]; then
  dump_where sgas_comercio_cta \
    "ts_operacion >= '${ccta_cut}' OR id_tr IN (SELECT id_tr FROM (SELECT MAX(id_tr) AS id_tr FROM sgas_comercio_cta GROUP BY cod_comercio, prod_id, nro_sucursal) x)"
fi

{
  echo "SET FOREIGN_KEY_CHECKS=1;"
} >> "$SEED_SQL"

echo "==> Compress → ${OUT_DIR}/02_seed.sql.gz"
gzip -9 -c "$SEED_SQL" > "${OUT_DIR}/02_seed.sql.gz"
rm -f "$SEED_SQL"

echo "Done."
ls -lh "${OUT_DIR}/01_schema.sql" "${OUT_DIR}/02_seed.sql.gz"
