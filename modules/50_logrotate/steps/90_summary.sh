#!/usr/bin/env bash
log_step "Validation de la configuration logrotate"

if ! logrotate -d /etc/logrotate.conf >/dev/null 2>&1; then
    log_error "La configuration logrotate contient une erreur."
    exit 1
fi

log ""
log "  Configuration logrotate .. OK"
[ -f /etc/logrotate.d/server-setup-caddy ] && log "  Logs Caddy ................ OK"
[ -f /etc/logrotate.d/server-setup-apps ] && log "  Logs applications ......... OK"
log ""
