#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$PROJECT_DIR/modules/20_docker"

log_module "Installation et configuration de Docker"

source "$MODULE_DIR/steps/10_user.sh"
source "$MODULE_DIR/steps/20_repository.sh"
source "$MODULE_DIR/steps/30_install.sh"
source "$MODULE_DIR/steps/40_daemon.sh"
source "$MODULE_DIR/steps/50_permissions.sh"
source "$MODULE_DIR/steps/90_summary.sh"

log_success "Docker Engine et Docker Compose sont installés et opérationnels."
