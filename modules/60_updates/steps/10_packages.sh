#!/usr/bin/env bash
log_step "Installation de unattended-upgrades"

run_quiet "Impossible de mettre à jour APT." apt-get update || exit 1
run_quiet "Impossible d'installer unattended-upgrades." \
    apt-get install -y unattended-upgrades || exit 1

log_info "unattended-upgrades installé."
