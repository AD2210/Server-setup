#!/usr/bin/env bash
log_step "Vérification des mises à jour automatiques"

UPDATE_TIMER=false
UPGRADE_TIMER=false
POLICY_OK=false

systemctl is-active --quiet apt-daily.timer && UPDATE_TIMER=true
systemctl is-active --quiet apt-daily-upgrade.timer && UPGRADE_TIMER=true
[ -r /etc/apt/apt.conf.d/52server-setup-unattended-upgrades ] && POLICY_OK=true

log ""
$UPDATE_TIMER && log "  apt-daily.timer ........... OK" || log_error "apt-daily.timer ........... ERREUR"
$UPGRADE_TIMER && log "  apt-daily-upgrade.timer ... OK" || log_error "apt-daily-upgrade.timer ... ERREUR"
$POLICY_OK && log "  Politique sécurité ........ OK" || log_error "Politique sécurité ........ ERREUR"
log ""

$UPDATE_TIMER && $UPGRADE_TIMER && $POLICY_OK || exit 1
