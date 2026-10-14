#!/usr/bin/env bash
set -euo pipefail
source /etc/server-setup/backup/backup.conf

EXCLUDES="/etc/server-setup/backup/excludes.txt"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="$LOCAL_BACKUP_ROOT/files-$STAMP"
REMOTE="${RCLONE_REMOTE}:${REMOTE_ROOT}/files/$STAMP"

mkdir -p "$WORK"
chmod 700 "$WORK"

ARGS=(--numeric-owner --xattrs --acls)
if [ -r "$EXCLUDES" ]; then
    while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        ARGS+=(--exclude="$pattern")
    done <"$EXCLUDES"
fi

SOURCES=(etc)
[ -d /opt/server-setup ] && SOURCES+=(opt/server-setup)
[ -d /opt/Server-setup ] && SOURCES+=(opt/Server-setup)
[ -d /srv/apps ] && SOURCES+=(srv/apps)
[ -d /srv/app ] && SOURCES+=(srv/app)

tar "${ARGS[@]}" -C / -cf - "${SOURCES[@]}" | zstd -T0 -q -o "$WORK/system.tar.zst"

(
    cd "$WORK"
    sha256sum system.tar.zst >SHA256SUMS
)
touch "$WORK/COMPLETE"

rclone copy "$WORK" "$REMOTE" --config "$RCLONE_CONFIG" --quiet
rclone lsf "$REMOTE" --config "$RCLONE_CONFIG" --files-only | grep -qx COMPLETE

find "$LOCAL_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'files-*' -mtime "+$LOCAL_RETENTION_DAYS" -exec rm -rf {} +

rclone delete "${RCLONE_REMOTE}:${REMOTE_ROOT}/files" --config "$RCLONE_CONFIG" --min-age "${REMOTE_RETENTION_DAYS}d" --quiet
rclone rmdirs "${RCLONE_REMOTE}:${REMOTE_ROOT}/files" --config "$RCLONE_CONFIG" --leave-root --quiet || true
