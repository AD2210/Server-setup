#!/usr/bin/env bash

## ============================================================================
## Étape 20 - Sécurisation SSH
##
## - sauvegarde sshd_config
## - bascule de ssh.socket vers ssh.service
## - détecte et modifie le port SSH
## - ouvre le nouveau port avant modification
## - désactive root et l'authentification par mot de passe
## - limite SSH au compte administrateur
## - valide la configuration et effectue un rollback en cas d'échec
## ============================================================================

log_step "Sécurisation du service SSH"

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak"

update_sshd_config() {
    local key="$1"
    local value="$2"
    local tmp_config
    tmp_config="$(mktemp)"
    # OpenSSH uses the first value read: managed global settings must precede
    # Include directives, notably cloud-init's PasswordAuthentication setting.
    {
        printf '%s %s\n' "$key" "$value"
        awk -v key="$key" '
            $1 == "Match" { in_match = 1 }
            !in_match && $1 == key { next }
            { print }
        ' "$SSHD_CONFIG"
    } > "$tmp_config"
    cat "$tmp_config" > "$SSHD_CONFIG"
    rm -f "$tmp_config"
}

rollback_ssh() {
    log_warn "Restauration de la configuration SSH précédente."

    cp "$SSHD_BACKUP" "$SSHD_CONFIG" || {
        log_error "Impossible de restaurer $SSHD_CONFIG."
        return 1
    }

    systemctl restart ssh >/dev/null 2>&1 || {
        log_error "Impossible de redémarrer SSH après rollback."
        return 1
    }

    log_info "Configuration SSH précédente restaurée."
}

if [ ! -f "$SSHD_CONFIG" ]; then
    log_error "Configuration SSH introuvable : $SSHD_CONFIG"
    exit 1
fi

cp "$SSHD_CONFIG" "$SSHD_BACKUP" || {
    log_error "Impossible de sauvegarder la configuration SSH."
    exit 1
}

log_info "Sauvegarde SSH créée : $SSHD_BACKUP"

run_quiet "Impossible de désactiver ssh.socket." \
    systemctl disable --now ssh.socket || exit 1

run_quiet "Impossible d'activer le service SSH." \
    systemctl enable --now ssh || exit 1

CURRENT_SSH_PORT="$(
    awk '/^[[:space:]]*Port[[:space:]]+[0-9]+/ { print $2; exit }' "$SSHD_CONFIG"
)"
CURRENT_SSH_PORT="${CURRENT_SSH_PORT:-22}"

log_info "Port SSH actuel : $CURRENT_SSH_PORT"

SSH_PORT=$(ask_input "Entre le nouveau port SSH" "$CURRENT_SSH_PORT" "SSH_PORT")

if [ -z "$SSH_PORT" ] \
    || ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] \
    || [ "$SSH_PORT" -lt 1 ] \
    || [ "$SSH_PORT" -gt 65535 ]; then
    log_error "Port SSH invalide : $SSH_PORT"
    log_info "Le port doit être compris entre 1 et 65535."
    exit 1
fi

# Sécurité critique : le nouveau port est ouvert avant le changement SSH.
run_quiet "Impossible d'autoriser le port SSH $SSH_PORT dans UFW." \
    ufw allow "$SSH_PORT/tcp" || exit 1

update_sshd_config "Port" "$SSH_PORT"
update_sshd_config "PermitRootLogin" "no"
update_sshd_config "PasswordAuthentication" "no"
update_sshd_config "KbdInteractiveAuthentication" "no"
update_sshd_config "PubkeyAuthentication" "yes"
update_sshd_config "AuthenticationMethods" "publickey"
update_sshd_config "PermitEmptyPasswords" "no"
update_sshd_config "AllowUsers" "$ADMIN_USER"

if ! sshd -t >/dev/null 2>&1; then
    log_error "La nouvelle configuration SSH est invalide."
    rollback_ssh || true

    if [ "$SSH_PORT" != "$CURRENT_SSH_PORT" ]; then
        ufw delete allow "$SSH_PORT/tcp" >/dev/null 2>&1 || true
    fi
    exit 1
fi

if ! run_quiet "Impossible de redémarrer le service SSH." systemctl restart ssh; then
    rollback_ssh || true
    exit 1
fi

if ! systemctl is-active --quiet ssh; then
    log_error "Le service SSH n'est pas actif."
    rollback_ssh || true
    exit 1
fi

if ! ss -H -ltn "sport = :$SSH_PORT" 2>/dev/null | grep -q .; then
    log_error "SSH n'écoute pas sur le port $SSH_PORT."
    rollback_ssh || true
    exit 1
fi

log_info "SSH opérationnel sur le port $SSH_PORT."
log_info "Accès root SSH désactivé."
log_info "Authentification SSH par mot de passe désactivée."
log_info "Utilisateur SSH autorisé : $ADMIN_USER"
