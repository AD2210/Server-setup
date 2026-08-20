#!/usr/bin/env bash
log_step "Contrôle de Server Setup"

FINAL_SETUP_OK=false
FINAL_SETUP_LINK_OK=false

if [ -n "${PROJECT_DIR:-}" ] && [ -d "$PROJECT_DIR" ]; then
    # shellcheck disable=SC2034
    FINAL_SETUP_OK=true
fi

if command -v setup >/dev/null 2>&1; then
    FINAL_SETUP_LINK_OK=true
fi

if ! $FINAL_SETUP_LINK_OK && [ -n "${PROJECT_DIR:-}" ] && [ -x "$PROJECT_DIR/bin/setup" ]; then
    ln -sf "$PROJECT_DIR/bin/setup" /usr/local/bin/setup
    FINAL_SETUP_LINK_OK=true
    log_info "Commande setup restaurée dans /usr/local/bin."
fi
