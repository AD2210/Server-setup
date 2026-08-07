#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$PROJECT_DIR/modules/40_backup"

log_module "Configuration des sauvegardes"

source "$MODULE_DIR/steps/10_packages.sh"
source "$MODULE_DIR/steps/20_rclone.sh"
source "$MODULE_DIR/steps/30_databases.sh"
source "$MODULE_DIR/steps/40_snapshots.sh"
source "$MODULE_DIR/steps/50_policy.sh"
source "$MODULE_DIR/steps/60_runtime.sh"
source "$MODULE_DIR/steps/70_systemd.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Plan de sauvegarde configuré avec succès."
