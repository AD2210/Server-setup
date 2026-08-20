#!/usr/bin/env bash

## ============================================================================
## Étape 90 - Contrôles finaux
## ============================================================================

log_step "Vérification de la sécurité du serveur"

SSH_OK=false
SSH_PORT_OK=false
SSH_CONFIG_OK=false
UFW_OK=false
FAIL2BAN_OK=false
ADMIN_OK=false
SUDO_OK=false

systemctl is-active --quiet ssh && SSH_OK=true

ss -H -ltn "sport = :$SSH_PORT" 2>/dev/null | grep -q . &&
    SSH_PORT_OK=true

sshd -t >/dev/null 2>&1 && SSH_CONFIG_OK=true

ufw status 2>/dev/null | grep -q "^Status: active" &&
    UFW_OK=true

systemctl is-active --quiet fail2ban &&
    FAIL2BAN_OK=true

id "$ADMIN_USER" >/dev/null 2>&1 &&
    ADMIN_OK=true

sudo -u "$ADMIN_USER" sudo -n true >/dev/null 2>&1 &&
    SUDO_OK=true

log ""

$SSH_OK &&
    log "  Service SSH .............. OK" ||
    log_error "Service SSH .............. ERREUR"

$SSH_PORT_OK &&
    log "  Port SSH ................. OK ($SSH_PORT)" ||
    log_error "Port SSH ................. ERREUR ($SSH_PORT)"

$SSH_CONFIG_OK &&
    log "  Configuration SSH ........ OK" ||
    log_error "Configuration SSH ........ ERREUR"

$ADMIN_OK &&
    log "  Utilisateur admin ........ OK ($ADMIN_USER)" ||
    log_error "Utilisateur admin ........ ERREUR"

$SUDO_OK &&
    log "  Sudo sans mot de passe ... OK" ||
    log_error "Sudo sans mot de passe ... ERREUR"

$UFW_OK &&
    log "  Pare-feu UFW ............. OK" ||
    log_error "Pare-feu UFW ............. ERREUR"

$FAIL2BAN_OK &&
    log "  Fail2ban ................. OK" ||
    log_error "Fail2ban ................. ERREUR"

log ""

if ! $SSH_OK ||
    ! $SSH_PORT_OK ||
    ! $SSH_CONFIG_OK ||
    ! $ADMIN_OK ||
    ! $SUDO_OK ||
    ! $UFW_OK ||
    ! $FAIL2BAN_OK; then

    log_error "La configuration de sécurité n'est pas complètement fonctionnelle."
    log_info "Consultez les erreurs ci-dessus avant de poursuivre."
    exit 1
fi
