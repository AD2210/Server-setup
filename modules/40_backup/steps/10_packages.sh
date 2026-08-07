#!/usr/bin/env bash
log_step "Installation des dépendances de sauvegarde"

run_quiet "Impossible de mettre à jour APT." apt-get update || exit 1
run_quiet "Impossible d'installer les dépendances."     apt-get install -y rclone zstd python3-venv || exit 1

for cmd in rclone zstd docker sha256sum python3; do
    command_exists "$cmd" || { log_error "Commande requise absente : $cmd"; exit 1; }
done

log_info "Dépendances disponibles."
