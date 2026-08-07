#!/usr/bin/env bash

## ============================================================================
## Étape 40 - Fail2ban
##
## - installe Fail2ban
## - déploie jail.local
## - adapte le port SSH
## - active et redémarre le service
## ============================================================================

log_step "Installation et configuration de Fail2ban"

FAIL2BAN_SOURCE="$PROJECT_DIR/config/jail.local"
FAIL2BAN_CONFIG="/etc/fail2ban/jail.local"

run_quiet "Impossible d'installer Fail2ban." \
    apt-get install -y fail2ban || exit 1

if [ ! -f "$FAIL2BAN_SOURCE" ]; then
    log_error "Configuration Fail2ban introuvable : $FAIL2BAN_SOURCE"
    exit 1
fi

cp "$FAIL2BAN_SOURCE" "$FAIL2BAN_CONFIG" || {
    log_error "Impossible d'installer la configuration Fail2ban."
    exit 1
}

if grep -qE '^[[:space:]]*port[[:space:]]*=' "$FAIL2BAN_CONFIG"; then
    sed -i -E \
        "s|^[[:space:]]*port[[:space:]]*=.*|port = $SSH_PORT|" \
        "$FAIL2BAN_CONFIG"
else
    log_warn "Aucune directive 'port =' trouvée dans jail.local."
    log_info "Vérifiez que le jail SSH utilise bien le port $SSH_PORT."
fi

run_quiet "Impossible d'activer Fail2ban au démarrage." \
    systemctl enable fail2ban || exit 1

run_quiet "Impossible de redémarrer Fail2ban." \
    systemctl restart fail2ban || exit 1

log_info "Fail2ban configuré pour le port SSH $SSH_PORT."
