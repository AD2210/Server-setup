#!/usr/bin/env bash
log_step "Configuration de la fréquence de redémarrage"

REBOOT_SCHEDULE="$(ask_input "Planification hebdomadaire (OnCalendar)" "Sun *-*-* 05:00:00")"

[ -n "$REBOOT_SCHEDULE" ] || {
    log_error "Planification vide."
    exit 1
}

log_info "Redémarrage planifié : $REBOOT_SCHEDULE"
