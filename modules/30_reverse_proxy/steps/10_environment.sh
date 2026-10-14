#!/usr/bin/env bash

## ============================================================================
## Étape 10 - Vérification de l'environnement
## ============================================================================

log_step "Préparation de l'environnement Caddy"

APPS_DIR="/srv/apps"
CADDYFILE="/etc/caddy/Caddyfile"
CADDY_DIR="/etc/caddy"
CADDY_SNIPPETS_DIR="$CADDY_DIR/snippets"
CADDY_APPS_DIR="$CADDY_DIR/apps"
DEPLOY_USER="${SUDO_USER:-root}"

if ! command_exists caddy; then
    log_error "Caddy n'est pas installé."
    exit 1
fi

if ! systemctl is-active --quiet caddy; then
    log_error "Le service Caddy n'est pas actif."
    log_info "Vérifiez : systemctl status caddy"
    exit 1
fi

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    log_error "Utilisateur de déploiement introuvable : $DEPLOY_USER"
    exit 1
fi

if [ ! -d "$APPS_DIR" ]; then
    log_info "Création du dossier applicatif $APPS_DIR."

    mkdir -p "$APPS_DIR"
    chown root:root "$APPS_DIR"
    chmod 755 "$APPS_DIR"
fi

install -d -m 755 -o root -g root "$CADDY_SNIPPETS_DIR" "$CADDY_APPS_DIR"
install -d -m 750 -o caddy -g caddy /var/log/caddy
if [[ ! -e /var/log/caddy/access.log ]]; then
    install -m 640 -o caddy -g caddy /dev/null /var/log/caddy/access.log
fi

if [ -e "$CADDYFILE" ] && { [ ! -r "$CADDYFILE" ] || [ ! -w "$CADDYFILE" ]; }; then
    log_error "Le Caddyfile n'est pas accessible en lecture/écriture."
    log_info "Fichier concerné : $CADDYFILE"
    exit 1
fi

log_info "Caddy opérationnel."
log_info "Utilisateur de déploiement : $DEPLOY_USER"
log_info "Dossier applicatif : $APPS_DIR"
