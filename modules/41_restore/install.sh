#!/usr/bin/env bash
## ============================================================================
## Module 41_restore
## Restauration des sauvegardes indépendantes du fournisseur
## ============================================================================
set -euo pipefail

MODULE_DIR="$PROJECT_DIR/modules/41_restore"

log_module "Restauration d'une sauvegarde"

source "$MODULE_DIR/steps/10_environment.sh"
source "$MODULE_DIR/steps/20_action.sh"

log_success "Opération de restauration terminée."
