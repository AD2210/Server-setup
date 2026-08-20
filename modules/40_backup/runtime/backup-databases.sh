#!/usr/bin/env bash
set -euo pipefail
source /etc/server-setup/backup/backup.conf

TARGETS="/etc/server-setup/backup/targets.d"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="$LOCAL_BACKUP_ROOT/db-$STAMP"
REMOTE="${RCLONE_REMOTE}:${REMOTE_ROOT}/databases/$STAMP"

mkdir -p "$WORK"
chmod 700 "$WORK"

for target in "$TARGETS"/*.conf; do
    [ -f "$target" ] || continue
    source "$target"

    (
        cd "$APP_DIR"
        docker compose -f "$COMPOSE_FILE" exec -T -e BACKUP_DB_NAME_ENV="$DB_NAME_ENV" -e BACKUP_DB_USER_ENV="$DB_USER_ENV" -e BACKUP_DB_PASSWORD_ENV="$DB_PASSWORD_ENV" "$DB_SERVICE" sh -lc '
                DB_NAME="$(printenv "$BACKUP_DB_NAME_ENV")"
                DB_USER="$(printenv "$BACKUP_DB_USER_ENV")"
                DB_PASSWORD="$(printenv "$BACKUP_DB_PASSWORD_ENV")"
                [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] || exit 20
                export PGPASSWORD="$DB_PASSWORD"
                exec pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc
            '
    ) >"$WORK/$TARGET_NAME.dump"
done

(
    cd "$WORK"
    find . -type f -name '*.dump' -print0 | sort -z | xargs -0 -r sha256sum >SHA256SUMS
)
touch "$WORK/COMPLETE"

rclone copy "$WORK" "$REMOTE" --config "$RCLONE_CONFIG" --quiet
rclone lsf "$REMOTE" --config "$RCLONE_CONFIG" --files-only | grep -qx COMPLETE

find "$LOCAL_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'db-*' -mtime "+$LOCAL_RETENTION_DAYS" -exec rm -rf {} +

rclone delete "${RCLONE_REMOTE}:${REMOTE_ROOT}/databases" --config "$RCLONE_CONFIG" --min-age "${REMOTE_RETENTION_DAYS}d" --quiet
rclone rmdirs "${RCLONE_REMOTE}:${REMOTE_ROOT}/databases" --config "$RCLONE_CONFIG" --leave-root --quiet || true
