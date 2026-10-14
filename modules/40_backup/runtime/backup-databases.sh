#!/usr/bin/env bash
set -euo pipefail
umask 077
exec 9>/run/lock/server-setup-backup-databases.lock
flock -w 600 9 || { echo 'Another database backup is still running.' >&2; exit 1; }
source /etc/server-setup/backup/backup.conf

TARGETS="/etc/server-setup/backup/targets.d"
if [[ "${DB_BACKUP_ENABLED:-false}" != true ]] || ! compgen -G "$TARGETS/*.conf" >/dev/null; then
    echo 'PostgreSQL backup is not configured: enable it and register database targets before deploying an existing stack.' >&2
    exit 1
fi
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="$LOCAL_BACKUP_ROOT/db-$STAMP"
REMOTE="${RCLONE_REMOTE}:${REMOTE_ROOT}/databases/$STAMP"

mkdir -p "$WORK"
chmod 700 "$WORK"

for target in "$TARGETS"/*.conf; do
    [ -f "$target" ] || continue
    COMPOSE_PROJECT_NAME=""
    source "$target"

    (
        cd "$APP_DIR"
        compose=(docker compose)
        [ -z "$COMPOSE_PROJECT_NAME" ] || compose+=(--project-name "$COMPOSE_PROJECT_NAME")
        "${compose[@]}" -f "$COMPOSE_FILE" exec -T             -e BACKUP_DB_NAME_ENV="$DB_NAME_ENV"             -e BACKUP_DB_USER_ENV="$DB_USER_ENV"             -e BACKUP_DB_PASSWORD_ENV="$DB_PASSWORD_ENV"             "$DB_SERVICE" sh -lc '
                DB_NAME="$(printenv "$BACKUP_DB_NAME_ENV")"
                DB_USER="$(printenv "$BACKUP_DB_USER_ENV")"
                DB_PASSWORD="$(printenv "$BACKUP_DB_PASSWORD_ENV")"
                [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] || exit 20
                case "$BACKUP_DB_PASSWORD_ENV" in
                    *_FILE)
                        [ -r "$DB_PASSWORD" ] || exit 21
                        DB_PASSWORD="$(cat "$DB_PASSWORD")"
                        ;;
                esac
                export PGPASSWORD="$DB_PASSWORD"
                exec pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc
            '
    ) > "$WORK/$TARGET_NAME.dump"
done

(cd "$WORK"; find . -type f -name '*.dump' -print0 | sort -z | xargs -0 -r sha256sum > SHA256SUMS)
touch "$WORK/COMPLETE"

rclone copy "$WORK" "$REMOTE" --config "$RCLONE_CONFIG" --quiet
rclone lsf "$REMOTE" --config "$RCLONE_CONFIG" --files-only | grep -qx COMPLETE

find "$LOCAL_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'db-*'     -mtime "+$LOCAL_RETENTION_DAYS" -exec rm -rf {} +

rclone delete "${RCLONE_REMOTE}:${REMOTE_ROOT}/databases"     --config "$RCLONE_CONFIG" --min-age "${REMOTE_RETENTION_DAYS}d" --quiet
rclone rmdirs "${RCLONE_REMOTE}:${REMOTE_ROOT}/databases"     --config "$RCLONE_CONFIG" --leave-root --quiet || true
