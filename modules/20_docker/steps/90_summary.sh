#!/usr/bin/env bash
log_step "Vérification de l'installation Docker"

DOCKER_OK=false
COMPOSE_OK=false
DAEMON_OK=false
CONTAINERD_OK=false
GROUP_OK=false
LIVE_RESTORE_OK=false

docker version >/dev/null 2>&1 && DOCKER_OK=true
docker compose version >/dev/null 2>&1 && COMPOSE_OK=true
systemctl is-active --quiet docker && DAEMON_OK=true
systemctl is-active --quiet containerd && CONTAINERD_OK=true
id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -qx docker && GROUP_OK=true
docker info --format '{{.LiveRestoreEnabled}}' 2>/dev/null | grep -qx true && LIVE_RESTORE_OK=true

log ""

$DOCKER_OK && log "  Docker Engine ............ OK" || log_error "Docker Engine ............ ERREUR"
$COMPOSE_OK && log "  Docker Compose ........... OK" || log_error "Docker Compose ........... ERREUR"
$DAEMON_OK && log "  Service Docker ........... OK" || log_error "Service Docker ........... ERREUR"
$CONTAINERD_OK && log "  Service containerd ....... OK" || log_error "Service containerd ...... ERREUR"
$GROUP_OK && log "  Droits utilisateur ....... OK ($ADMIN_USER)" || log_error "Droits utilisateur ...... ERREUR ($ADMIN_USER)"
$LIVE_RESTORE_OK && log "  Live restore ............. OK" || log_error "Live restore ............. ERREUR"

log ""

$DOCKER_OK && log_info "$(docker --version 2>/dev/null)"
$COMPOSE_OK && log_info "$(docker compose version 2>/dev/null)"

if ! $DOCKER_OK || ! $COMPOSE_OK || ! $DAEMON_OK || ! $CONTAINERD_OK || ! $GROUP_OK || ! $LIVE_RESTORE_OK; then
    log_error "L'installation Docker n'est pas complètement fonctionnelle."
    log_info "Consultez les erreurs ci-dessus avant de poursuivre."
    exit 1
fi

if [ "$USER_GROUP_UPDATED" = true ]; then
    log_warn "Les nouveaux droits Docker ne sont pas actifs dans la session actuelle."
    log_info "Déconnectez-vous puis reconnectez-vous avant d'utiliser Docker sans sudo."
fi
