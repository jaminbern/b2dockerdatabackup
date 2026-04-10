FROM alpine:3.20

RUN apk add --no-cache \
    postgresql16-client \
    mysql-client \
    python3 \
    py3-pip \
    bash \
    curl \
    gzip \
    openssl \
    && pip3 install --break-system-packages b2sdk

COPY backup.sh /backup.sh
COPY restore.sh /restore.sh
RUN chmod +x /backup.sh /restore.sh

# Default schedule: 3 AM UTC daily
ENV BACKUP_CRON="0 3 * * *"
ENV BACKUP_RETENTION_DAYS=30

CMD echo "${BACKUP_CRON} /backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root \
    && echo "Backup scheduled: ${BACKUP_CRON}" \
    && touch /var/log/backup.log \
    && /backup.sh >> /var/log/backup.log 2>&1 \
    && crond -f -l 2 & tail -f /var/log/backup.log
