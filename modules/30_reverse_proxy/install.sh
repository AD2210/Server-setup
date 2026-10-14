#!/usr/bin/env bash

## ============================================================================
## Module 30_reverse_proxy
## Orchestration de la configuration du reverse proxy Caddy
##
## Étapes :
## - vérification de l'environnement Caddy et /srv/apps
## - inventaire des ports HTTP et DB déjà utilisés
## - saisie et validation des endpoints
## - préparation du dossier applicatif
## - affichage des indications Compose / .env
## - génération, validation et rechargement du Caddyfile
## - contrôles finaux
##
## Les prérequis globaux sont contrôlés par bin/setup.
## ============================================================================

set -euo pipefail

MODULE_DIR="$PROJECT_DIR/modules/30_reverse_proxy"

log_module "Configuration du reverse proxy Caddy"

source "$MODULE_DIR/steps/10_environment.sh"
source "$MODULE_DIR/steps/15_shared_config.sh"
if [[ "${PROXY_SHARED_ONLY:-false}" == true ]]; then
    log_success "Configuration Caddy partagée installée ; endpoints applicatifs conservés."
    return 0
fi
source "$MODULE_DIR/steps/20_inventory.sh"
source "$MODULE_DIR/steps/30_endpoints.sh"
source "$MODULE_DIR/steps/40_application.sh"
source "$MODULE_DIR/steps/50_caddy.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Configuration du reverse proxy terminée avec succès."
