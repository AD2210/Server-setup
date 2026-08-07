#!/usr/bin/env bash
log_step "Vérification du plan de sauvegarde"

RCLONE_OK=false
DB_OK=true
FILES_OK=true
PROVIDER_OK=true

rclone lsd "${RCLONE_REMOTE}:" --config "$RCLONE_CONFIG" >/dev/null 2>&1 && RCLONE_OK=true

if $DB_BACKUP_ENABLED; then
    [ -x /usr/local/lib/server-setup/backup-databases.sh ] &&     systemctl is-active --quiet server-setup-backup-db.timer || DB_OK=false
fi

if $FILES_BACKUP_ENABLED; then
    [ -x /usr/local/lib/server-setup/backup-files.sh ] &&     systemctl is-active --quiet server-setup-backup-files.timer || FILES_OK=false
fi

if $PROVIDER_BACKUP_ENABLED; then
    [ -x /usr/local/lib/server-setup/backup-provider-snapshot.sh ] &&     systemctl is-active --quiet server-setup-backup-provider.timer || PROVIDER_OK=false
fi

log ""
$RCLONE_OK && log "  Stockage rclone .......... OK ($RCLONE_REMOTE)" || log_error "Stockage rclone .......... ERREUR"

$DB_BACKUP_ENABLED     && { $DB_OK && log "  Backup PostgreSQL ........ OK" || log_error "Backup PostgreSQL ........ ERREUR"; }     || log "  Backup PostgreSQL ........ DÉSACTIVÉ"

$FILES_BACKUP_ENABLED     && { $FILES_OK && log "  Snapshot logique ......... OK" || log_error "Snapshot logique ......... ERREUR"; }     || log "  Snapshot logique ......... DÉSACTIVÉ"

$PROVIDER_BACKUP_ENABLED     && { $PROVIDER_OK && log "  Snapshot provider ........ OK ($PROVIDER_NAME)" || log_error "Snapshot provider ........ ERREUR"; }     || log "  Snapshot provider ........ DÉSACTIVÉ"

log ""

if ! $RCLONE_OK || ! $DB_OK || ! $FILES_OK || ! $PROVIDER_OK; then
    log_error "Le plan de sauvegarde n'est pas complètement fonctionnel."
    exit 1
fi
