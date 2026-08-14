#!/usr/bin/env bash
set -euo pipefail

# Backup sertantai-legal to NAS: database snapshots + project data files.
# Usage: ./nas-backup.sh [--archive] [--db-only] [--data-only]
#   --archive:   move current latest/ to archive/ before exporting DB
#   --db-only:   skip project data sync
#   --data-only: skip database snapshot

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NAS_DIR="/mnt/nas/sertantai-data/data"
SNAPSHOT_DIR="${NAS_DIR}/snapshots/latest"
ARCHIVE_DIR="${NAS_DIR}/snapshots/archive"
NAS_DATA_DIR="${NAS_DIR}/project-data"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5436}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-sertantai_legal_dev}"

# Tables to snapshot (order matters for FK dependencies on restore)
TABLES=(
  legal_register_uk
  legal_register_au
  legal_articles_uk
  legal_articles_au
  amendment_annotations
  controls
  control_mappings
  secondary_sources
  source_links
  secondary_source_provisions
  org_applicabilities
  org_secondary_applicabilities
  org_screening_profiles
  org_entitlements
  sync_profiles
  sync_configurations
  organizations
  legislative_definitions
  scrape_sessions
  scrape_session_records
  cascade_affected_laws
  law_edges
  si_code_families
)

# Project data directory to sync (gitignored, not in GitHub)
DATA_DIR="data"

# Parse flags
DO_DB=true
DO_DATA=true
DO_ARCHIVE=false

for arg in "$@"; do
  case "$arg" in
    --archive)   DO_ARCHIVE=true ;;
    --db-only)   DO_DATA=false ;;
    --data-only) DO_DB=false ;;
  esac
done

# Check NAS is mounted
if [ ! -d "$NAS_DIR" ]; then
  echo "ERROR: NAS not mounted at $NAS_DIR"
  echo "Try: ls /mnt/nas/sertantai-data  (auto-mounts via fstab)"
  exit 1
fi

echo "=== sertantai-legal NAS Backup ==="
echo "  NAS: ${NAS_DIR}"
echo "  DB:  ${DO_DB} | Data: ${DO_DATA} | Archive: ${DO_ARCHIVE}"
echo ""

# =========================================================================
# Stage 1: Database snapshot
# =========================================================================

if [ "$DO_DB" = true ]; then
  echo "--- Stage 1: Database Snapshot ---"

  # Archive previous snapshot if requested
  if [ "$DO_ARCHIVE" = true ] && [ -f "${SNAPSHOT_DIR}/manifest.json" ]; then
    prev_date=$(jq -r '.date' "${SNAPSHOT_DIR}/manifest.json" 2>/dev/null || echo "unknown")
    archive_name="${prev_date:-$(date +%Y-%m-%d)}"
    echo "Archiving previous snapshot to ${ARCHIVE_DIR}/${archive_name}/"
    mkdir -p "${ARCHIVE_DIR}/${archive_name}"
    mv "${SNAPSHOT_DIR}"/*.dump "${ARCHIVE_DIR}/${archive_name}/" 2>/dev/null || true
    mv "${SNAPSHOT_DIR}/manifest.json" "${ARCHIVE_DIR}/${archive_name}/" 2>/dev/null || true
  fi

  mkdir -p "$SNAPSHOT_DIR"

  echo "Exporting dev database..."
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

    # Check table exists before dumping
    exists=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      -t -A -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '${table}')")

    if [ "$exists" != "t" ]; then
      echo "SKIP (not found)"
      continue
    fi

    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      --table="$table" --data-only --format=custom --compress=6 \
      -f "$dump_file"

    count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      -t -A -c "SELECT count(*) FROM ${table}")

    size=$(stat --format='%s' "$dump_file")
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
  echo "DB snapshot complete."
  echo ""
fi

# =========================================================================
# Stage 2: Project data sync
# =========================================================================

if [ "$DO_DATA" = true ]; then
  echo "--- Stage 2: Project Data Sync ---"

  # Sync project-level data/ (secondary sources, etc.)
  src="${PROJECT_DIR}/${DATA_DIR}"
  dest="${NAS_DATA_DIR}/${DATA_DIR}"

  if [ -d "$src" ]; then
    mkdir -p "$dest"
    echo "  rsync ${DATA_DIR}/ → ${dest}/"
    rsync -a --delete "$src/" "$dest/"
    file_count=$(find "$src" -type f | wc -l)
    dir_size=$(du -sh "$src" | cut -f1)
    echo "    ${file_count} files, ${dir_size}"
  else
    echo "  SKIP ${DATA_DIR} (not found)"
  fi

  # Sync backend/data/ (QQ working data, SQLite DBs, imports, reports)
  backend_data="${PROJECT_DIR}/backend/data"
  backend_dest="${NAS_DATA_DIR}/backend-data"

  if [ -d "$backend_data" ]; then
    mkdir -p "$backend_dest"
    echo "  rsync backend/data/ → ${backend_dest}/"
    rsync -a --delete "$backend_data/" "$backend_dest/"
    file_count=$(find "$backend_data" -type f | wc -l)
    dir_size=$(du -sh "$backend_data" | cut -f1)
    echo "    ${file_count} files, ${dir_size}"
  else
    echo "  SKIP backend/data (not found)"
  fi

  echo ""
  echo "Data sync complete."
  echo ""
fi

echo "=== Backup finished ==="
