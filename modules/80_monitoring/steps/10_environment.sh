#!/usr/bin/env bash

## ============================================================================
## Étape 10 - Vérification de l'environnement monitoring
## ============================================================================

log_step "Vérification de l'environnement monitoring"

command_exists curl || {
    log_error "curl est requis pour installer le monitoring."
    exit 1
}
command_exists caddy || {
    log_error "Caddy doit être installé avant le monitoring."
    exit 1
}
systemctl is-active --quiet caddy || {
    log_error "Le service Caddy doit être actif avant l'installation d'Ember."
    exit 1
}

MONITORING_CONFIG_DIR="/etc/server-setup/monitoring"
VECTOR_CONFIG_DIR="/etc/vector"
VECTOR_ENV_FILE="$MONITORING_CONFIG_DIR/vector.env"
VECTOR_CONFIG_FILE="$VECTOR_CONFIG_DIR/vector.toml"

install -d -m 750 -o root -g root "$MONITORING_CONFIG_DIR"
install -d -m 755 -o root -g root "$VECTOR_CONFIG_DIR"

wait_for_apt "$(config_get APT_WAIT_TIMEOUT 600)" "$(config_get APT_WAIT_INTERVAL 5)"
