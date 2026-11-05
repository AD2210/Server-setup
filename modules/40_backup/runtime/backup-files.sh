#!/usr/bin/env bash
set -euo pipefail
umask 077
exec 9>/run/lock/server-setup-backup-files.lock
flock -w 600 9
source /etc/server-setup/backup/backup.conf
source /usr/local/lib/server-setup/backup-retention.sh

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

if [[ "${REMOTE_BACKUP_ENABLED:-true}" = true ]]; then
    rclone copy "$WORK" "$REMOTE" --config "$RCLONE_CONFIG" --quiet
    rclone check "$WORK" "$REMOTE" --config "$RCLONE_CONFIG" --one-way --quiet
    prune_remote_backups files "$STAMP"
else
    echo 'Local files backup complete; remote transfer is disabled by configuration.'
fi
prune_local_backups files "$STAMP"
