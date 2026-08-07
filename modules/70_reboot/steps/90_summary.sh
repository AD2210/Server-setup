#!/usr/bin/env bash
log_step "Vérification du redémarrage périodique"

if ! systemctl is-active --quiet server-setup-reboot.timer; then
    log_error "Le timer de redémarrage n'est pas actif."
    exit 1
fi

NEXT="$(systemctl list-timers server-setup-reboot.timer --no-legend 2>/dev/null | awk '{$1=$1};1')"

log ""
log "  Timer reboot .............. OK"
[ -n "$NEXT" ] && log_info "Prochaine exécution : $NEXT"
log ""

if [ -f /var/run/reboot-required ]; then
    log_warn "Un redémarrage est actuellement requis par le système."
fi
