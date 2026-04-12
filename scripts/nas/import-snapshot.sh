#!/usr/bin/env bash
set -euo pipefail

# Restore dev database tables from NAS snapshots.
# Usage: ./import-snapshot.sh [--verify-only]
#   --verify-only: check checksums and row counts without restoring

NAS_DIR="/mnt/nas/sertantai-data/data"
SNAPSHOT_DIR="${NAS_DIR}/snapshots/latest"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5436}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-sertantai_legal_dev}"

# Restore order: parents before children (FK dependencies)
TABLES=(
  uk_lrt
  lat
  amendment_annotations
  scrape_sessions
  scrape_session_records
  cascade_affected_laws
)

# Check NAS is mounted and snapshot exists
if [ ! -d "$SNAPSHOT_DIR" ]; then
  echo "ERROR: Snapshot directory not found at $SNAPSHOT_DIR"
  echo "Is the NAS mounted? Try: sudo mount /mnt/nas/sertantai-data"
  exit 1
fi

if [ ! -f "${SNAPSHOT_DIR}/manifest.json" ]; then
  echo "ERROR: No manifest.json found in ${SNAPSHOT_DIR}"
  exit 1
fi

echo "Snapshot manifest:"
jq '.' "${SNAPSHOT_DIR}/manifest.json"
echo ""

# Verify checksums
echo "Verifying checksums..."
all_ok=true
for table in "${TABLES[@]}"; do
  dump_file="${SNAPSHOT_DIR}/${table}.dump"
  if [ ! -f "$dump_file" ]; then
    echo "  MISSING: ${table}.dump"
    all_ok=false
    continue
  fi

  expected=$(jq -r ".tables.\"${table}\".sha256" "${SNAPSHOT_DIR}/manifest.json")
  actual=$(sha256sum "$dump_file" | cut -d' ' -f1)

  if [ "$expected" = "$actual" ]; then
    rows=$(jq -r ".tables.\"${table}\".rows" "${SNAPSHOT_DIR}/manifest.json")
    echo "  OK: ${table} (${rows} rows)"
  else
    echo "  CHECKSUM MISMATCH: ${table}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual}"
    all_ok=false
  fi
done

if [ "$all_ok" != true ]; then
  echo ""
  echo "ERROR: Verification failed. Aborting."
  exit 1
fi

if [[ "${1:-}" == "--verify-only" ]]; then
  echo ""
  echo "Verification passed. Use without --verify-only to restore."
  exit 0
fi

export PGPASSWORD="${PGPASSWORD:-postgres}"

echo ""
echo "Restoring to ${DB_HOST}:${DB_PORT}/${DB_NAME}..."
echo "This will REPLACE existing data in the tables listed above."
read -rp "Continue? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
for table in "${TABLES[@]}"; do
  dump_file="${SNAPSHOT_DIR}/${table}.dump"
  expected_rows=$(jq -r ".tables.\"${table}\".rows" "${SNAPSHOT_DIR}/manifest.json")

  echo -n "  ${table} (${expected_rows} rows)... "

  # Truncate existing data (CASCADE handles FK references)
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -q -c "TRUNCATE ${table} CASCADE;"

  # Restore
  pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --data-only --no-owner --no-privileges --disable-triggers \
    "$dump_file"

  # Verify row count
  actual_rows=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -t -A -c "SELECT count(*) FROM ${table}")

  if [ "$actual_rows" -eq "$expected_rows" ]; then
    echo "OK (${actual_rows} rows)"
  else
    echo "WARNING: expected ${expected_rows}, got ${actual_rows}"
  fi
done

echo ""
echo "Restore complete."
