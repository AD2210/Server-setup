#!/usr/bin/env bash

## ============================================================================
## Module 30_reverse_proxy
## Orchestration de la configuration du reverse proxy Caddy
##
## Étapes :
## - vérification de l'environnement Caddy et /srv/apps
## - installation du Caddyfile serveur de référence
## - installation des snippets communs
## - préparation des répertoires snippets et applications
## - validation et rechargement du Caddyfile
## - contrôles finaux
##
## Les prérequis globaux sont contrôlés par bin/setup.
## ============================================================================

set -euo pipefail

MODULE_DIR="$PROJECT_DIR/modules/30_reverse_proxy"

log_module "Configuration du reverse proxy Caddy"

source "$MODULE_DIR/steps/10_environment.sh"
source "$MODULE_DIR/steps/50_caddy.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Configuration du reverse proxy terminée avec succès."
