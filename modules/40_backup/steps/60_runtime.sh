#!/usr/bin/env bash
log_step "Installation des runtimes de sauvegarde"

RUNTIME_DIR="/usr/local/lib/server-setup"
install -d -m 755 -o root -g root "$RUNTIME_DIR"

# Keep the production CD backup hook present even while a fresh server has no
# database targets. Scheduling remains controlled by DB_BACKUP_ENABLED.
install -m 700 -o root -g root "$MODULE_DIR/runtime/backup-databases.sh" "$RUNTIME_DIR/backup-databases.sh"

$FILES_BACKUP_ENABLED && install -m 700 -o root -g root     "$MODULE_DIR/runtime/backup-files.sh" "$RUNTIME_DIR/backup-files.sh"

$PROVIDER_BACKUP_ENABLED && install -m 700 -o root -g root     "$MODULE_DIR/runtime/backup-provider-snapshot.sh" "$RUNTIME_DIR/backup-provider-snapshot.sh"

log_info "Runtimes actifs installés."
