#!/usr/bin/env bash

## ============================================================================
## Étape 30 - Pare-feu UFW
##
## - applique les politiques par défaut
## - autorise HTTP/HTTPS
## - active UFW
## - demande validation avant fermeture de l'ancien port SSH
## - propose la suppression du compte fournisseur
## ============================================================================

log_step "Configuration du pare-feu UFW"

remove_initial_user() {
    local user="$1"

    if [ "$user" = "root" ]; then
        log_info "Le compte root est conservé avec accès SSH désactivé."
        return 0
    fi

    if ! id "$user" >/dev/null 2>&1; then
        log_info "Le compte '$user' n'existe plus."
        return 0
    fi

    userdel -r "$user" || {
        log_error "Impossible de supprimer l'utilisateur '$user'."
        return 1
    }

    log_info "Utilisateur initial '$user' supprimé."
}

# Le port 22 est conservé pendant la transition uniquement s'il s'agit
# effectivement de l'ancien port.
if [ "$CURRENT_SSH_PORT" = "22" ] && [ "$SSH_PORT" != "22" ]; then
    run_quiet "Impossible d'autoriser temporairement le port SSH 22." \
        ufw allow 22/tcp || exit 1
fi

run_quiet "Impossible de définir la politique entrante UFW." \
    ufw default deny incoming || exit 1

run_quiet "Impossible de définir la politique sortante UFW." \
    ufw default allow outgoing || exit 1

run_quiet "Impossible d'autoriser HTTP." \
    ufw allow 80/tcp || exit 1

run_quiet "Impossible d'autoriser HTTPS." \
    ufw allow 443/tcp || exit 1

run_quiet "Impossible d'activer UFW." \
    ufw --force enable || exit 1

log_info "Pare-feu UFW actif."

if [ "$CURRENT_SSH_PORT" != "$SSH_PORT" ]; then
    log ""
    log_warn "IMPORTANT : validez le nouvel accès avant de fermer l'ancien."
    log ""
    log "  1. Ouvrez un nouveau terminal."
    log "  2. Connectez-vous avec :"
    log "     ssh -p $SSH_PORT $ADMIN_USER@[ip]"
    log "  3. Vérifiez les privilèges :"
    log "     sudo whoami"
    log "  4. Résultat attendu : root"
    log ""

    if confirm "Fermer l'ancien port SSH ($CURRENT_SSH_PORT) ?"; then
        if run_quiet \
            "Impossible de supprimer la règle UFW du port $CURRENT_SSH_PORT." \
            ufw delete allow "$CURRENT_SSH_PORT/tcp"; then
            log_info "Ancien port SSH $CURRENT_SSH_PORT fermé."
        else
            log_warn "Ancien port SSH $CURRENT_SSH_PORT conservé."
        fi
    else
        log_info "Ancien port SSH $CURRENT_SSH_PORT conservé."
    fi
fi

if [ "$INITIAL_USER" != "root" ] && [ "$INITIAL_USER" != "$ADMIN_USER" ]; then
    log_step "Gestion de l'utilisateur fournisseur"

    log_warn "Ne supprimez '$INITIAL_USER' qu'après avoir validé la connexion avec '$ADMIN_USER'."

    if confirm "Supprimer l'utilisateur initial '$INITIAL_USER' ?"; then
        remove_initial_user "$INITIAL_USER" || exit 1
    else
        log_info "Utilisateur '$INITIAL_USER' conservé."
    fi
else
    log_info "Compte root conservé avec accès SSH désactivé."
fi
