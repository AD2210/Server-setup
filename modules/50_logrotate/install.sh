#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$PROJECT_DIR/modules/50_logrotate"

log_module "Configuration de la rotation des logs"

source "$MODULE_DIR/steps/10_environment.sh"
source "$MODULE_DIR/steps/20_caddy.sh"
source "$MODULE_DIR/steps/30_apps.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Rotation des logs configurée avec succès."
