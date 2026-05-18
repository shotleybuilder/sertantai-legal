#!/usr/bin/env bash
set -euo pipefail

# Export dev database tables to NAS as pg_dump custom-format snapshots.
# Usage: ./export-snapshot.sh [--archive]
#   --archive: move current latest/ to archive/ before exporting

NAS_DIR="/mnt/nas/sertantai-data/data"
SNAPSHOT_DIR="${NAS_DIR}/snapshots/latest"
ARCHIVE_DIR="${NAS_DIR}/snapshots/archive"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5436}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-sertantai_legal_dev}"

# Tables to snapshot (order matters for FK dependencies on restore)
# After partition migration: uk_lrt → legal_register_uk, lat → legal_articles_uk
TABLES=(
  legal_register_uk
  legal_articles_uk
  amendment_annotations
  scrape_sessions
  scrape_session_records
  cascade_affected_laws
  law_edges
  si_code_families
)

# Check NAS is mounted
if [ ! -d "$NAS_DIR" ]; then
  echo "ERROR: NAS not mounted at $NAS_DIR"
  exit 1
fi

# Archive previous snapshot if --archive flag
if [[ "${1:-}" == "--archive" ]] && [ -f "${SNAPSHOT_DIR}/manifest.json" ]; then
  prev_date=$(jq -r '.date' "${SNAPSHOT_DIR}/manifest.json" 2>/dev/null || echo "unknown")
  archive_name="${prev_date:-$(date +%Y-%m-%d)}"
  echo "Archiving previous snapshot to ${ARCHIVE_DIR}/${archive_name}/"
  mkdir -p "${ARCHIVE_DIR}/${archive_name}"
  mv "${SNAPSHOT_DIR}"/*.dump "${ARCHIVE_DIR}/${archive_name}/" 2>/dev/null || true
  mv "${SNAPSHOT_DIR}/manifest.json" "${ARCHIVE_DIR}/${archive_name}/" 2>/dev/null || true
fi

mkdir -p "$SNAPSHOT_DIR"

echo "Exporting dev database snapshot to NAS..."
echo "  Host: ${DB_HOST}:${DB_PORT}"
echo "  Database: ${DB_NAME}"
echo "  Target: ${SNAPSHOT_DIR}"
echo ""

export PGPASSWORD="${PGPASSWORD:-postgres}"

# Build manifest
manifest='{'
manifest+="\"date\": \"$(date -Iseconds)\","
manifest+="\"database\": \"${DB_NAME}\","
manifest+="\"host\": \"${DB_HOST}:${DB_PORT}\","
manifest+="\"tables\": {"

first=true
for table in "${TABLES[@]}"; do
  echo -n "  ${table}... "

  dump_file="${SNAPSHOT_DIR}/${table}.dump"

  pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --table="$table" --data-only --format=custom --compress=6 \
    -f "$dump_file"

  # Get row count
  count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -t -A -c "SELECT count(*) FROM ${table}")

  # Get file size
  size=$(stat --format='%s' "$dump_file")

  # Get checksum
  checksum=$(sha256sum "$dump_file" | cut -d' ' -f1)

  echo "${count} rows ($(numfmt --to=iec "$size"))"

  if [ "$first" = true ]; then
    first=false
  else
    manifest+=","
  fi
  manifest+="\"${table}\": {\"rows\": ${count}, \"size\": ${size}, \"sha256\": \"${checksum}\"}"
done

manifest+="}}"

echo "$manifest" | jq '.' > "${SNAPSHOT_DIR}/manifest.json"

echo ""
echo "Snapshot complete. Manifest:"
jq '.' "${SNAPSHOT_DIR}/manifest.json"
