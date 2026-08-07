#!/usr/bin/env bash
log_step "Contrôle de sécurité"

FINAL_UFW_OK=false
FINAL_SSH_OK=false

if command_exists ufw && ufw status 2>/dev/null | grep -q "^Status: active"; then
    FINAL_UFW_OK=true
else
    log_warn "UFW n'est pas actif."
fi

if sshd -t >/dev/null 2>&1; then
    FINAL_SSH_OK=true
else
    log_warn "La configuration SSH est invalide."
fi

if [ -f /var/run/reboot-required ]; then
    FINAL_REBOOT_REQUIRED=true
else
    FINAL_REBOOT_REQUIRED=false
fi
