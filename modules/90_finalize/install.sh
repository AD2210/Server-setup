#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$PROJECT_DIR/modules/90_finalize"

log_module "Finalisation et contrôle du serveur"

source "$MODULE_DIR/steps/10_system.sh"
source "$MODULE_DIR/steps/20_services.sh"
source "$MODULE_DIR/steps/30_timers.sh"
source "$MODULE_DIR/steps/40_security.sh"
source "$MODULE_DIR/steps/50_setup.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Contrôle final terminé."
