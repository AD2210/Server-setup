#!/usr/bin/env bash
log_step "Vérification de logrotate"

if ! command_exists logrotate; then
    run_quiet "Impossible d'installer logrotate." apt-get install -y logrotate || exit 1
fi

[ -d /etc/logrotate.d ] || {
    log_error "Répertoire /etc/logrotate.d introuvable."
    exit 1
}

log_info "logrotate disponible."
