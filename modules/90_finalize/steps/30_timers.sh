#!/usr/bin/env bash
log_step "Contrôle des timers"

FINAL_TIMER_ERRORS=()
FINAL_TIMERS=(
    apt-daily.timer
    apt-daily-upgrade.timer
    server-setup-reboot.timer
    server-setup-backup-db.timer
    server-setup-backup-files.timer
    server-setup-backup-provider.timer
)

for timer in "${FINAL_TIMERS[@]}"; do
    if systemctl list-unit-files "$timer" --no-legend 2>/dev/null | grep -q .; then
        if systemctl is-active --quiet "$timer"; then
            log_info "$timer : actif"
        else
            FINAL_TIMER_ERRORS+=("$timer")
            log_warn "$timer : inactif"
        fi
    fi
done
