#!/usr/bin/env bash
## Étape 60 - Installation des runtimes

log_step "Installation des runtimes de sauvegarde"

RUNTIME_DIR="/usr/local/lib/server-setup"
install -d -m 755 -o root -g root "$RUNTIME_DIR"

for script in backup-databases.sh backup-files.sh backup-provider-snapshot.sh; do
    source_file="$MODULE_DIR/runtime/$script"
    [ -f "$source_file" ] || {
        log_error "Runtime absent : $source_file"
        exit 1
    }
    install -m 700 -o root -g root "$source_file" "$RUNTIME_DIR/$script"
done

log_info "Runtimes installés."
