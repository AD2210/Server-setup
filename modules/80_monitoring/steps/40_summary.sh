#!/usr/bin/env bash

## ============================================================================
## Étape 40 - Contrôles finaux du monitoring
## ============================================================================

log_step "Contrôle du monitoring"

EMBER_OK=false
VECTOR_OK=false
VECTOR_CONFIG_OK=false

command_exists ember && EMBER_OK=true
command_exists vector && VECTOR_OK=true
vector validate "$VECTOR_CONFIG_FILE" >/dev/null 2>&1 && VECTOR_CONFIG_OK=true

$EMBER_OK \
    && log "  Ember .................... OK" \
    || log_error "Ember .................... ERREUR"

$VECTOR_OK \
    && log "  Vector ................... OK" \
    || log_error "Vector ................... ERREUR"

$VECTOR_CONFIG_OK \
    && log "  Configuration Vector ..... OK" \
    || log_error "Configuration Vector ..... ERREUR"

if grep -q 'CHANGE_ME' "$VECTOR_ENV_FILE"; then
    log_warn "Vector reste désactivé tant que son endpoint central n'est pas renseigné."
elif ! systemctl is-active --quiet vector; then
    log_error "Le service Vector n'est pas actif."
    exit 1
fi

log_info "Les logs Caddy runtime restent disponibles via : journalctl -u caddy"
