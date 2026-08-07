#!/usr/bin/env bash
## Étape 20 - Stockage distant rclone

log_step "Configuration du stockage distant"

RCLONE_DIR="/etc/rclone"
RCLONE_CONFIG="$RCLONE_DIR/rclone.conf"

install -d -m 700 -o root -g root "$RCLONE_DIR"
touch "$RCLONE_CONFIG"
chmod 600 "$RCLONE_CONFIG"

if ! rclone listremotes --config "$RCLONE_CONFIG" 2>/dev/null | grep -q .; then
    log_warn "Aucun remote rclone configuré."
    log_info "Configurez Google Drive puis, de préférence, un remote crypt dédié."
    rclone config --config "$RCLONE_CONFIG"
fi

REMOTES="$(rclone listremotes --config "$RCLONE_CONFIG" 2>/dev/null | sed 's/:$//' | tr '\n' ' ')"

[ -n "$REMOTES" ] || {
    log_error "Aucun remote rclone disponible."
    exit 1
}

log_info "Remotes disponibles : $REMOTES"

RCLONE_REMOTE="$(ask_input "Remote utilisé pour les sauvegardes" "backup")"

rclone listremotes --config "$RCLONE_CONFIG" | grep -qx "${RCLONE_REMOTE}:" || {
    log_error "Remote inconnu : $RCLONE_REMOTE"
    exit 1
}

run_quiet "Impossible d'accéder au remote '$RCLONE_REMOTE'." \
    rclone lsd "${RCLONE_REMOTE}:" --config "$RCLONE_CONFIG" || exit 1

log_info "Remote '$RCLONE_REMOTE' opérationnel."
