#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
PROJECT_NAME="${PROJECT_NAME:-backup}"
ERRORS=0

mkdir -p "${BACKUP_DIR}"

# ─── B2 Upload Function ────────────────────────────────────────────

upload_to_b2() {
    local FPATH="$1"
    local FNAME="$2"

    if [ -z "${B2_APPLICATION_KEY_ID:-}" ] || [ -z "${B2_APPLICATION_KEY:-}" ] || [ -z "${B2_BUCKET_NAME:-}" ]; then
        return 0
    fi

    local PREFIX="${B2_PREFIX:-${PROJECT_NAME}}"

    python3 -c "
import b2sdk.v2 as b2
import os, sys
try:
    info = b2.InMemoryAccountInfo()
    api = b2.B2Api(info)
    api.authorize_account('production',
        os.environ['B2_APPLICATION_KEY_ID'],
        os.environ['B2_APPLICATION_KEY'])
    bucket = api.get_bucket_by_name(os.environ['B2_BUCKET_NAME'])
    remote = '${PREFIX}/${FNAME}'
    bucket.upload_local_file(local_file='${FPATH}', file_name=remote)
    print(f'  -> B2: {remote}')
except Exception as e:
    print(f'  B2 upload failed: {e}', file=sys.stderr)
"
}

# ─── Start ──────────────────────────────────────────────────────────

echo "============================================"
echo "[$(date)] Backup started — project: ${PROJECT_NAME}"
echo "============================================"

# ─── PostgreSQL Databases ───────────────────────────────────────────
# Format: "label:host:port:user:password:dbname,label2:host2:..."

if [ -n "${POSTGRES_DATABASES:-}" ]; then
    IFS=',' read -ra PG_LIST <<< "${POSTGRES_DATABASES}"
    for entry in "${PG_LIST[@]}"; do
        IFS=':' read -r LABEL HOST PORT USER PASS DBNAME <<< "${entry}"
        FILENAME="${PROJECT_NAME}_pg_${LABEL}_${TIMESTAMP}.sql.gz"
        FILEPATH="${BACKUP_DIR}/${FILENAME}"

        echo "[$(date)] Dumping PostgreSQL: ${LABEL} (${DBNAME}@${HOST})..."
        if PGPASSWORD="${PASS}" pg_dump -h "${HOST}" -p "${PORT}" -U "${USER}" -d "${DBNAME}" --no-owner --no-privileges 2>/tmp/pg_err | gzip > "${FILEPATH}"; then
            FILESIZE=$(du -h "${FILEPATH}" | cut -f1)
            echo "[$(date)]   OK ${FILENAME} (${FILESIZE})"
            upload_to_b2 "${FILEPATH}" "${FILENAME}"
        else
            echo "[$(date)]   FAILED: $(cat /tmp/pg_err)"
            ERRORS=$((ERRORS + 1))
            rm -f "${FILEPATH}"
        fi
    done
fi

# ─── MySQL/MariaDB Databases ───────────────────────────────────────
# Format: "label:host:port:user:password:dbname,..."

if [ -n "${MYSQL_DATABASES:-}" ]; then
    IFS=',' read -ra MY_LIST <<< "${MYSQL_DATABASES}"
    for entry in "${MY_LIST[@]}"; do
        IFS=':' read -r LABEL HOST PORT USER PASS DBNAME <<< "${entry}"
        FILENAME="${PROJECT_NAME}_my_${LABEL}_${TIMESTAMP}.sql.gz"
        FILEPATH="${BACKUP_DIR}/${FILENAME}"

        echo "[$(date)] Dumping MySQL: ${LABEL} (${DBNAME}@${HOST})..."
        if mysqldump -h "${HOST}" -P "${PORT}" -u "${USER}" -p"${PASS}" --single-transaction --routines --triggers "${DBNAME}" 2>/tmp/my_err | gzip > "${FILEPATH}"; then
            FILESIZE=$(du -h "${FILEPATH}" | cut -f1)
            echo "[$(date)]   OK ${FILENAME} (${FILESIZE})"
            upload_to_b2 "${FILEPATH}" "${FILENAME}"
        else
            echo "[$(date)]   FAILED: $(cat /tmp/my_err)"
            ERRORS=$((ERRORS + 1))
            rm -f "${FILEPATH}"
        fi
    done
fi

# ─── File/Directory Backups ─────────────────────────────────────────
# Format: "label:/path/to/dir,label2:/other/path"

if [ -n "${BACKUP_PATHS:-}" ]; then
    IFS=',' read -ra PATH_LIST <<< "${BACKUP_PATHS}"
    for entry in "${PATH_LIST[@]}"; do
        LABEL="${entry%%:*}"
        BPATH="${entry#*:}"
        FILENAME="${PROJECT_NAME}_files_${LABEL}_${TIMESTAMP}.tar.gz"
        FILEPATH="${BACKUP_DIR}/${FILENAME}"

        echo "[$(date)] Archiving files: ${LABEL} (${BPATH})..."
        if [ -d "${BPATH}" ]; then
            if tar czf "${FILEPATH}" -C "$(dirname "${BPATH}")" "$(basename "${BPATH}")" 2>/tmp/tar_err; then
                FILESIZE=$(du -h "${FILEPATH}" | cut -f1)
                echo "[$(date)]   OK ${FILENAME} (${FILESIZE})"
                upload_to_b2 "${FILEPATH}" "${FILENAME}"
            else
                echo "[$(date)]   FAILED: $(cat /tmp/tar_err)"
                ERRORS=$((ERRORS + 1))
                rm -f "${FILEPATH}"
            fi
        else
            echo "[$(date)]   Path not found: ${BPATH}"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

# ─── Clean up old local backups ─────────────────────────────────────

if [ -n "${BACKUP_RETENTION_DAYS:-}" ] && [ "${BACKUP_RETENTION_DAYS}" -gt 0 ]; then
    DELETED=$(find "${BACKUP_DIR}" -name "${PROJECT_NAME}_*" -mtime "+${BACKUP_RETENTION_DAYS}" -delete -print | wc -l)
    if [ "${DELETED}" -gt 0 ]; then
        echo "[$(date)] Cleaned up ${DELETED} old backup(s)."
    fi
fi

# ─── Summary ────────────────────────────────────────────────────────

echo "--------------------------------------------"
if [ "${ERRORS}" -gt 0 ]; then
    echo "[$(date)] Completed with ${ERRORS} error(s)."
    exit 1
else
    echo "[$(date)] All backups completed successfully."
fi
