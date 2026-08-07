#!/usr/bin/env bash
log_step "Configuration du daemon Docker"

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
BACKUP_FILE=""

mkdir -p /etc/docker

if [ -f "$DOCKER_DAEMON_FILE" ]; then
    BACKUP_FILE="${DOCKER_DAEMON_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$DOCKER_DAEMON_FILE" "$BACKUP_FILE" || {
        log_error "Impossible de sauvegarder daemon.json."
        exit 1
    }
    log_info "Sauvegarde créée : $BACKUP_FILE"
fi

cat > "$DOCKER_DAEMON_FILE" <<'EOF'
{
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "5"
  }
}
EOF

chmod 644 "$DOCKER_DAEMON_FILE"

python3 -m json.tool "$DOCKER_DAEMON_FILE" >/dev/null 2>&1 || {
    log_error "Le fichier $DOCKER_DAEMON_FILE contient un JSON invalide."
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        log_warn "Restauration de la configuration précédente."
        cp "$BACKUP_FILE" "$DOCKER_DAEMON_FILE" || true
    fi
    exit 1
}

log_info "Configuration daemon.json valide."

run_quiet "Impossible d'activer docker.service."     systemctl enable docker.service || exit 1

run_quiet "Impossible d'activer containerd.service."     systemctl enable containerd.service || exit 1

if systemctl is-active --quiet docker; then
    if ! run_quiet "Le rechargement du daemon Docker a échoué."         systemctl reload docker; then

        log_warn "Tentative de redémarrage complet du daemon Docker."

        if ! run_quiet "Impossible de redémarrer Docker."             systemctl restart docker; then

            if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
                log_warn "Rollback de la configuration Docker."
                cp "$BACKUP_FILE" "$DOCKER_DAEMON_FILE" || true
                systemctl restart docker >/dev/null 2>&1 || true
            fi
            exit 1
        fi
    fi
else
    run_quiet "Impossible de démarrer Docker."         systemctl start docker || exit 1
fi

log_info "Daemon Docker configuré et actif."
