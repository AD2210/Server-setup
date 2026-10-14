#!/usr/bin/env bash
log_step "Installation du gestionnaire de releases Docker"

SOURCE="$MODULE_DIR/runtime/server-release.sh"
TARGET="/usr/local/bin/server-release"

[ -f "$SOURCE" ] || {
    log_error "Runtime de releases introuvable : $SOURCE"
    exit 1
}

install -m 755 -o root -g root "$SOURCE" "$TARGET"
log_info "Gestionnaire installé : $TARGET"

install -m 755 -o root -g root "$MODULE_DIR/runtime/server-api-config.sh" /usr/local/bin/server-api-config
log_info "Distribution des API installée : /usr/local/bin/server-api-config"
