#!/usr/bin/env bash
log_step "Configuration du stockage distant"

RCLONE_DIR="/etc/rclone"
RCLONE_CONFIG="$RCLONE_DIR/rclone.conf"

install -d -m 700 -o root -g root "$RCLONE_DIR"
touch "$RCLONE_CONFIG"
chmod 600 "$RCLONE_CONFIG"

REMOTES="$(rclone listremotes --config "$RCLONE_CONFIG" 2>/dev/null || true)"

if [ -n "$REMOTES" ]; then
    log_info "Remotes rclone existantes :"
    while IFS= read -r remote; do
        [ -n "$remote" ] && log "  ${remote%:}"
    done <<<"$REMOTES"

    KEEP_RCLONE_CONFIG=false
    if $NON_INTERACTIVE; then
        if confirm_required "Conserver la configuration rclone existante ?" "RCLONE_KEEP_EXISTING"; then
            KEEP_RCLONE_CONFIG=true
        elif [ "$?" -eq 2 ]; then
            exit 1
        fi
    elif confirm "Conserver la configuration rclone existante ?"; then
        KEEP_RCLONE_CONFIG=true
    fi

    if ! $KEEP_RCLONE_CONFIG; then
        if $NON_INTERACTIVE; then
            log_error "La reconfiguration rclone nécessite une action interactive."
            exit 1
        fi
        rclone config --config "$RCLONE_CONFIG"
        REMOTES="$(rclone listremotes --config "$RCLONE_CONFIG" 2>/dev/null || true)"
    fi
else
    log_warn "Aucune remote rclone configurée."

    if $NON_INTERACTIVE; then
        log_error "Aucune remote rclone configurée en mode non interactif."
        log_info "Préparez $RCLONE_CONFIG avant de relancer le module."
        exit 1
    fi

    rclone config --config "$RCLONE_CONFIG"
    REMOTES="$(rclone listremotes --config "$RCLONE_CONFIG" 2>/dev/null || true)"
fi

[ -n "$REMOTES" ] || {
    log_error "Aucune remote rclone disponible."
    exit 1
}

DEFAULT_REMOTE="$(head -n1 <<<"$REMOTES" | sed 's/:$//')"
RCLONE_REMOTE="$(ask_input "Remote utilisée pour les sauvegardes" "$DEFAULT_REMOTE" "RCLONE_REMOTE")"

rclone listremotes --config "$RCLONE_CONFIG" | grep -qx "${RCLONE_REMOTE}:" || {
    log_error "Remote inconnue : $RCLONE_REMOTE"
    exit 1
}

run_quiet "Impossible d'accéder à la remote '$RCLONE_REMOTE'." rclone lsd "${RCLONE_REMOTE}:" --config "$RCLONE_CONFIG" || exit 1

log_info "Remote '$RCLONE_REMOTE' opérationnelle."
