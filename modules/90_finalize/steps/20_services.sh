#!/usr/bin/env bash
log_step "Contrôle des services"

FINAL_SERVICE_ERRORS=()
FINAL_SERVICES=(ssh caddy docker containerd fail2ban)

for service in "${FINAL_SERVICES[@]}"; do
    if systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q .; then
        if systemctl is-active --quiet "$service"; then
            log_info "$service : actif"
        else
            FINAL_SERVICE_ERRORS+=("$service")
            log_warn "$service : inactif"
        fi
    fi
done
