#!/usr/bin/env bash
log_step "Vérification de l'environnement de restauration"

BACKUP_CONFIG="/etc/server-setup/backup/backup.conf"
TARGETS_DIR="/etc/server-setup/backup/targets.d"
RESTORE_ROOT="/var/lib/server-setup/restore"

install -d -m 700 -o root -g root "$RESTORE_ROOT"

if [ -r "$BACKUP_CONFIG" ]; then
    source "$BACKUP_CONFIG"
fi
