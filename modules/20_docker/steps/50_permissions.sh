#!/usr/bin/env bash
log_step "Configuration des droits utilisateur Docker"

USER_GROUP_UPDATED=false

if ! getent group docker >/dev/null 2>&1; then
    run_quiet "Impossible de créer le groupe docker." groupadd docker || exit 1
    log_info "Groupe docker créé."
fi

if id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -qx docker; then
    log_info "L'utilisateur '$ADMIN_USER' appartient déjà au groupe docker."
else
    run_quiet "Impossible d'ajouter '$ADMIN_USER' au groupe docker." usermod -aG docker "$ADMIN_USER" || exit 1
    USER_GROUP_UPDATED=true
    log_info "Utilisateur '$ADMIN_USER' ajouté au groupe docker."
fi
