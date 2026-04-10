#!/bin/bash
set -e

# Create log file
touch /var/log/backup.log

# Set up cron schedule
echo "${BACKUP_CRON} /backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root
echo "Backup scheduled: ${BACKUP_CRON}"

# Run initial backup on startup
echo "Running initial backup..."
/backup.sh >> /var/log/backup.log 2>&1 || true

# Start cron in background
crond -l 2

# Follow the log
tail -f /var/log/backup.log
