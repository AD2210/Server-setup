#!/usr/bin/env bash
## Étape 90 - Résumé

log_step "Vérification du plan de sauvegarde"

RCLONE_OK=false
CONFIG_OK=false
DB_RUNTIME_OK=false
FILES_RUNTIME_OK=false
PROVIDER_RUNTIME_OK=false
TIMERS_OK=true

rclone lsd "${RCLONE_REMOTE}:" --config "$RCLONE_CONFIG" >/dev/null 2>&1 && RCLONE_OK=true
[ -r "$BACKUP_CONFIG" ] && CONFIG_OK=true
[ -x /usr/local/lib/server-setup/backup-databases.sh ] && DB_RUNTIME_OK=true
[ -x /usr/local/lib/server-setup/backup-files.sh ] && FILES_RUNTIME_OK=true
[ -x /usr/local/lib/server-setup/backup-provider-snapshot.sh ] && PROVIDER_RUNTIME_OK=true

for timer in \
    server-setup-backup-db.timer \
    server-setup-backup-files.timer \
    server-setup-backup-provider.timer; do
    systemctl is-active --quiet "$timer" || TIMERS_OK=false
done

log ""
$RCLONE_OK && log "  Stockage rclone .......... OK" || log_error "Stockage rclone .......... ERREUR"
$CONFIG_OK && log "  Configuration ............ OK" || log_error "Configuration ............ ERREUR"
$DB_RUNTIME_OK && log "  Backup PostgreSQL ........ OK" || log_error "Backup PostgreSQL ........ ERREUR"
$FILES_RUNTIME_OK && log "  Snapshot logique ......... OK" || log_error "Snapshot logique ......... ERREUR"
if [ "$PROVIDER_NAME" = "none" ]; then
    log "  Snapshot provider ........ DÉSACTIVÉ"
else
    $PROVIDER_RUNTIME_OK \
        && log "  Snapshot provider ........ OK ($PROVIDER_NAME)" \
        || log_error "Snapshot provider ........ ERREUR"
fi
$TIMERS_OK && log "  Timers systemd ........... OK" || log_error "Timers systemd ........... ERREUR"
log ""

if ! $RCLONE_OK || ! $CONFIG_OK || ! $DB_RUNTIME_OK || ! $FILES_RUNTIME_OK || ! $PROVIDER_RUNTIME_OK || ! $TIMERS_OK; then
    log_error "Le plan de sauvegarde n'est pas complètement fonctionnel."
    exit 1
fi

log_info "Tests manuels recommandés :"
log "  systemctl start server-setup-backup-db.service"
log "  systemctl start server-setup-backup-files.service"
log "  systemctl start server-setup-backup-provider.service"
