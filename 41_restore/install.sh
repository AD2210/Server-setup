#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$PROJECT_DIR/modules/41_restore"

log_module "Restauration"

source "$MODULE_DIR/steps/10_environment.sh"
source "$MODULE_DIR/steps/20_action.sh"
source "$MODULE_DIR/steps/30_release.sh"

case "${RESTORE_ACTION:-}" in
    3) restore_release ;;
esac

log_success "Opération de restauration terminée."
