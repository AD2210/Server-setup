#!/usr/bin/env bash

## ============================================================================
## Étape 90 - Contrôles finaux
## ============================================================================

log_step "Vérification de la configuration reverse proxy"

CADDY_OK=false
CADDY_CONFIG_OK=false
CADDY_STRUCTURE_OK=false

systemctl is-active --quiet caddy && CADDY_OK=true

caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1 &&
    CADDY_CONFIG_OK=true

[ -d "$CADDY_SNIPPETS_DIR" ] &&
    [ -d "$CADDY_APPS_DIR" ] &&
    [ -f "$CADDYFILE" ] &&
    CADDY_STRUCTURE_OK=true

log ""

$CADDY_OK &&
    log "  Service Caddy ............ OK" ||
    log_error "Service Caddy ............ ERREUR"

$CADDY_CONFIG_OK &&
    log "  Configuration Caddy ...... OK" ||
    log_error "Configuration Caddy ...... ERREUR"

$CADDY_STRUCTURE_OK &&
    log "  Arborescence Caddy ....... OK" ||
    log_error "Arborescence Caddy ....... ERREUR"

log ""
log_info "Endpoints applicatifs gérés par la CD :"
find "$CADDY_APPS_DIR" -maxdepth 1 -type f -name '*.caddy' -printf '  %f\n' 2>/dev/null ||
    log "  Aucun fichier applicatif."

log ""

if ! $CADDY_OK || ! $CADDY_CONFIG_OK || ! $CADDY_STRUCTURE_OK; then
    log_error "La configuration reverse proxy n'est pas complètement fonctionnelle."
    log_info "Consultez les erreurs ci-dessus avant de poursuivre."
    exit 1
fi
