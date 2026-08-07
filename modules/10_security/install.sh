#!/usr/bin/env bash

## ============================================================================
## Module 10_security
## Orchestration de la sécurisation du serveur
##
## Étapes :
## - création/configuration du compte administrateur
## - sécurisation SSH
## - configuration UFW
## - installation/configuration Fail2ban
## - contrôles finaux
##
## Les prérequis globaux sont contrôlés par bin/setup.
## ============================================================================

set -euo pipefail

MODULE_DIR="$PROJECT_DIR/modules/10_security"

log_module "Sécurisation des accès au serveur"

source "$MODULE_DIR/steps/10_admin_user.sh"
source "$MODULE_DIR/steps/20_ssh.sh"
source "$MODULE_DIR/steps/30_ufw.sh"
source "$MODULE_DIR/steps/40_fail2ban.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Sécurisation du serveur terminée avec succès."
