#!/usr/bin/env bash
# Stream only completed snapshots while holding the producers' locks.
set -euo pipefail
umask 077
[[ $EUID = 0 ]] || {
    echo 'Run with sudo.' >&2
    exit 1
}
source /etc/server-setup/backup/backup.conf
exec 9>/run/lock/server-setup-backup-databases.lock
flock -s -w 600 9
exec 8>/run/lock/server-setup-backup-files.lock
flock -s -w 600 8
snapshots=()
for prefix in db files; do
    selected=''
    while IFS= read -r name; do
        [[ "$name" =~ ^(db|files)-[0-9]{8}T[0-9]{6}Z$ ]] || continue
        if [[ -f "$LOCAL_BACKUP_ROOT/$name/COMPLETE" ]]; then
            selected="$name"
            break
        fi
    done < <(find "$LOCAL_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name "$prefix-*" -printf '%f\n' | sort -r)
    [[ -n "$selected" ]] || {
        echo "No complete $prefix snapshot available." >&2
        exit 1
    }
    snapshots+=("$selected")
done
case "${1:-}" in
    --manifest)
        cd "$LOCAL_BACKUP_ROOT"
        sha256sum "${snapshots[0]}/SHA256SUMS" "${snapshots[1]}/SHA256SUMS"
        ;;
    --archive)
        tar -C "$LOCAL_BACKUP_ROOT" -czf - -- "${snapshots[@]}"
        ;;
    *)
        echo 'Usage: sudo server-backup-export {--manifest|--archive}' >&2
        exit 2
        ;;
esac
