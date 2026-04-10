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
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /backup.sh /restore.sh /entrypoint.sh

ENV BACKUP_CRON="0 3 * * *"
ENV BACKUP_RETENTION_DAYS=30

CMD ["/entrypoint.sh"]
