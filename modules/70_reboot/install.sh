#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$PROJECT_DIR/modules/70_reboot"

log_module "Configuration du redémarrage périodique"

source "$MODULE_DIR/steps/10_schedule.sh"
source "$MODULE_DIR/steps/20_systemd.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Redémarrage périodique configuré avec succès."
