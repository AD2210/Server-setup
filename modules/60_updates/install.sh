#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$PROJECT_DIR/modules/60_updates"

log_module "Configuration des mises à jour automatiques"

source "$MODULE_DIR/steps/10_packages.sh"
source "$MODULE_DIR/steps/20_policy.sh"
source "$MODULE_DIR/steps/30_apt_timer.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Mises à jour automatiques configurées avec succès."
