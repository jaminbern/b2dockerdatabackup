#!/bin/bash
set -euo pipefail

# Usage:
#   restore.sh pg <host> <port> <user> <password> <dbname> <backup_file.sql.gz>
#   restore.sh mysql <host> <port> <user> <password> <dbname> <backup_file.sql.gz>
#   restore.sh files <backup_file.tar.gz> <target_dir>

TYPE="${1:-}"
shift || true

case "${TYPE}" in
    pg|postgres)
        HOST="$1"; PORT="$2"; USER="$3"; PASS="$4"; DBNAME="$5"; FILE="$6"
        echo "Restoring PostgreSQL: ${DBNAME}@${HOST} from ${FILE}..."
        gunzip -c "${FILE}" | PGPASSWORD="${PASS}" psql -h "${HOST}" -p "${PORT}" -U "${USER}" -d "${DBNAME}"
        echo "Done."
        ;;
    my|mysql)
        HOST="$1"; PORT="$2"; USER="$3"; PASS="$4"; DBNAME="$5"; FILE="$6"
        echo "Restoring MySQL: ${DBNAME}@${HOST} from ${FILE}..."
        gunzip -c "${FILE}" | mysql -h "${HOST}" -P "${PORT}" -u "${USER}" -p"${PASS}" "${DBNAME}"
        echo "Done."
        ;;
    files)
        FILE="$1"; TARGET="${2:-.}"
        echo "Restoring files from ${FILE} to ${TARGET}..."
        tar xzf "${FILE}" -C "${TARGET}"
        echo "Done."
        ;;
    *)
        echo "Usage:"
        echo "  restore.sh pg <host> <port> <user> <pass> <dbname> <file.sql.gz>"
        echo "  restore.sh mysql <host> <port> <user> <pass> <dbname> <file.sql.gz>"
        echo "  restore.sh files <file.tar.gz> [target_dir]"
        exit 1
        ;;
esac
