# docker-backup

Lightweight Docker container for automated database and file backups with Backblaze B2 upload.

## Features

- **PostgreSQL** backup (pg_dump, compressed)
- **MySQL/MariaDB** backup (mysqldump, compressed)
- **File/directory** backup (tar.gz)
- **Backblaze B2** upload
- **Cron scheduling** (configurable)
- **Local retention** cleanup
- **Restore script** included
- **Multiple databases** in one container

## Quick Start

Add to your `docker-compose.yml`:

```yaml
backup:
  image: ghcr.io/jaminbern/docker-backup:latest
  environment:
    - PROJECT_NAME=myapp
    - POSTGRES_DATABASES=main:db:5432:postgres:${DB_PASSWORD}:my_database
    - B2_APPLICATION_KEY_ID=${B2_KEY_ID}
    - B2_APPLICATION_KEY=${B2_KEY}
    - B2_BUCKET_NAME=my-backups
  volumes:
    - backups:/backups
  depends_on:
    db:
      condition: service_healthy
  restart: unless-stopped
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PROJECT_NAME` | No | `backup` | Prefix for backup filenames |
| `BACKUP_CRON` | No | `0 3 * * *` | Cron schedule (default: 3 AM UTC) |
| `BACKUP_RETENTION_DAYS` | No | `30` | Days to keep local backups |
| `POSTGRES_DATABASES` | No | | Comma-separated `label:host:port:user:pass:dbname` |
| `MYSQL_DATABASES` | No | | Comma-separated `label:host:port:user:pass:dbname` |
| `BACKUP_PATHS` | No | | Comma-separated `label:/path` for file backups |
| `B2_APPLICATION_KEY_ID` | No | | Backblaze B2 key ID |
| `B2_APPLICATION_KEY` | No | | Backblaze B2 application key |
| `B2_BUCKET_NAME` | No | | B2 bucket name |
| `B2_PREFIX` | No | `PROJECT_NAME` | B2 path prefix |

### Multiple Databases

```
POSTGRES_DATABASES=app:db:5432:postgres:pass:app_db,analytics:db:5432:postgres:pass:analytics_db
```

### File Backups

Mount directories as read-only volumes and list them:

```yaml
environment:
  - BACKUP_PATHS=uploads:/data/uploads,documents:/data/docs
volumes:
  - /srv/myapp/uploads:/data/uploads:ro
  - /srv/myapp/documents:/data/docs:ro
```

## Manual Operations

```bash
# Run backup now
docker compose exec backup /backup.sh

# Restore PostgreSQL
docker compose exec backup /restore.sh pg db 5432 postgres secret my_database /backups/myapp_pg_main_20260410.sql.gz

# Restore MySQL
docker compose exec backup /restore.sh mysql db 3306 root secret my_database /backups/myapp_my_main_20260410.sql.gz

# Restore files
docker compose exec backup /restore.sh files /backups/myapp_files_uploads_20260410.tar.gz /data/uploads

# View backup logs
docker compose logs backup

# List backups
docker compose exec backup ls -lh /backups/
```

## Backup File Naming

```
{PROJECT_NAME}_{type}_{label}_{YYYYMMDD_HHMMSS}.{ext}
```

Examples:
- `myapp_pg_main_20260410_030000.sql.gz`
- `myapp_my_analytics_20260410_030000.sql.gz`
- `myapp_files_uploads_20260410_030000.tar.gz`
