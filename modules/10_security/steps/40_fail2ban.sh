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

fail2ban_tmp="$(mktemp)"
awk -v ssh_port="$SSH_PORT" '
    /^\[/ { section = $0 }
    section == "[sshd]" && /^[[:space:]]*port[[:space:]]*=/ {
        print "port = " ssh_port
        next
    }
    { print }
' "$FAIL2BAN_CONFIG" > "$fail2ban_tmp"
cat "$fail2ban_tmp" > "$FAIL2BAN_CONFIG"
rm -f "$fail2ban_tmp"

# The template does not ship a Caddy filter. An enabled jail referencing a
# missing filter prevents Fail2ban from starting, including SSH protection.
if [ ! -f /etc/fail2ban/filter.d/caddy.conf ]; then
    fail2ban_tmp="$(mktemp)"
    awk '
        /^\[/ { section = $0 }
        section == "[caddy]" && /^[[:space:]]*enabled[[:space:]]*=/ {
            print "enabled = false"
            next
        }
        { print }
    ' "$FAIL2BAN_CONFIG" > "$fail2ban_tmp"
    cat "$fail2ban_tmp" > "$FAIL2BAN_CONFIG"
    rm -f "$fail2ban_tmp"
    log_warn "Jail Caddy désactivée : filtre caddy.conf absent. Protection SSH conservée."
fi

run_quiet "Configuration Fail2ban invalide." fail2ban-client -t || exit 1

run_quiet "Impossible d'activer Fail2ban au démarrage." \
    systemctl enable fail2ban || exit 1

run_quiet "Impossible de redémarrer Fail2ban." \
    systemctl restart fail2ban || exit 1

log_info "Fail2ban configuré pour le port SSH $SSH_PORT."
