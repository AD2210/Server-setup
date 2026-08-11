#!/usr/bin/env bash
log_step "Choix de la restauration"

log ""
log "  1) Restaurer une base PostgreSQL"
log "  2) Extraire un snapshot logique en staging"
log "  3) Restaurer une release Docker"
log "  4) Procédure de disaster recovery"
log ""

RESTORE_ACTION="$(ask_input "Choix" "3" "RESTORE_ACTION")"

case "$RESTORE_ACTION" in
    1)
        log_info "Restauration PostgreSQL : conserver ici votre logique existante."
        ;;
    2)
        log_info "Restauration snapshot logique : conserver ici votre logique existante."
        ;;
    3)
        ;;
    4)
        log ""
        log "  1. Restaurer/recréer le VPS."
        log "  2. Réinstaller Server Setup."
        log "  3. Restaurer fichiers et bases."
        log "  4. Recharger la dernière release Docker stable."
        log ""
        ;;
    *)
        log_error "Choix invalide : $RESTORE_ACTION"
        exit 1
        ;;
esac
