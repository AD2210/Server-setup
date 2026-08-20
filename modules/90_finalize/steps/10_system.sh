#!/usr/bin/env bash
log_step "Contrôle général du système"

FINAL_OS_OK=false
FINAL_DISK_OK=false

if [ -r /etc/os-release ]; then
    source /etc/os-release
    # shellcheck disable=SC2034
    [ "${ID:-}" = "ubuntu" ] && FINAL_OS_OK=true
fi

ROOT_USAGE="$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')"
if [[ "$ROOT_USAGE" =~ ^[0-9]+$ ]] && [ "$ROOT_USAGE" -lt 90 ]; then
    # shellcheck disable=SC2034
    FINAL_DISK_OK=true
else
    log_warn "Utilisation disque racine élevée : ${ROOT_USAGE:-?}%"
fi
