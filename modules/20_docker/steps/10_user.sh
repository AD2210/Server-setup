#!/usr/bin/env bash
log_step "Détection de l'utilisateur administrateur"

ADMIN_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"

if [ -z "$ADMIN_USER" ] || [ "$ADMIN_USER" = "root" ]; then
    log_warn "Impossible de détecter automatiquement l'utilisateur administrateur."
    ADMIN_USER=$(ask_input "Utilisateur à autoriser à utiliser Docker" "")
    [ -n "$ADMIN_USER" ] || { log_error "Aucun utilisateur renseigné."; exit 1; }
fi

id "$ADMIN_USER" >/dev/null 2>&1 || {
    log_error "L'utilisateur '$ADMIN_USER' n'existe pas."
    exit 1
}

log_info "Utilisateur administrateur : $ADMIN_USER"
