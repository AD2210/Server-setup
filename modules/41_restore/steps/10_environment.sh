#!/usr/bin/env bash
log_step "Vérification de l'environnement de restauration"

BACKUP_CONFIG="/etc/server-setup/backup/backup.conf"
# shellcheck disable=SC2034
TARGETS_DIR="/etc/server-setup/backup/targets.d"
RESTORE_ROOT="/var/lib/server-setup/restore"

[ -r "$BACKUP_CONFIG" ] || {
    log_error "Configuration backup absente : $BACKUP_CONFIG"
    exit 1
}

# shellcheck disable=SC1090
source "$BACKUP_CONFIG"
install -d -m 700 -o root -g root "$RESTORE_ROOT"

run_quiet "Stockage distant inaccessible." \
    rclone lsd "${RCLONE_REMOTE}:${REMOTE_ROOT}" --config "$RCLONE_CONFIG" || exit 1
