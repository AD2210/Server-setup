#!/usr/bin/env bash
log_step "Résumé final"

FINAL_OK=true

log ""
$FINAL_OS_OK && log "  Ubuntu .................... OK" || { log_error "Ubuntu .................... ERREUR"; FINAL_OK=false; }
$FINAL_DISK_OK && log "  Espace disque ............. OK (${ROOT_USAGE}%)" || { log_error "Espace disque ............. ALERTE"; FINAL_OK=false; }
$FINAL_SSH_OK && log "  Configuration SSH ........ OK" || { log_error "Configuration SSH ........ ERREUR"; FINAL_OK=false; }
$FINAL_UFW_OK && log "  Pare-feu UFW .............. OK" || { log_error "Pare-feu UFW .............. ERREUR"; FINAL_OK=false; }
$FINAL_SETUP_OK && log "  Server Setup .............. OK" || { log_error "Server Setup .............. ERREUR"; FINAL_OK=false; }
$FINAL_SETUP_LINK_OK && log "  Commande setup ............ OK" || { log_error "Commande setup ............ ERREUR"; FINAL_OK=false; }

if [ "${#FINAL_SERVICE_ERRORS[@]}" -eq 0 ]; then
    log "  Services critiques ........ OK"
else
    log_error "Services inactifs ......... ${FINAL_SERVICE_ERRORS[*]}"
    FINAL_OK=false
fi

if [ "${#FINAL_TIMER_ERRORS[@]}" -eq 0 ]; then
    log "  Timers configurés ......... OK"
else
    log_error "Timers inactifs ........... ${FINAL_TIMER_ERRORS[*]}"
    FINAL_OK=false
fi

$FINAL_REBOOT_REQUIRED && log_warn "Un redémarrage système est requis."

log ""

if ! $FINAL_OK; then
    log_error "Le serveur nécessite une intervention avant validation finale."
    exit 1
fi

log_info "Serveur prêt pour exploitation."
