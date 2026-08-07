#!/usr/bin/env bash
log_step "Installation de Docker Engine et Docker Compose"

run_quiet "Impossible d'installer Docker Engine."     apt-get install -y         docker-ce docker-ce-cli containerd.io         docker-buildx-plugin docker-compose-plugin || exit 1

log_info "Paquets Docker installés."
