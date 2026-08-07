#!/usr/bin/env bash
log_step "Activation des timers APT"

run_quiet "Impossible d'activer apt-daily.timer." \
    systemctl enable --now apt-daily.timer || exit 1

run_quiet "Impossible d'activer apt-daily-upgrade.timer." \
    systemctl enable --now apt-daily-upgrade.timer || exit 1

log_info "Timers APT activés."
