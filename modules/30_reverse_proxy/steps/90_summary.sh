#!/usr/bin/env bash

## ============================================================================
## Étape 90 - Contrôles finaux
## ============================================================================

log_step "Vérification de la configuration reverse proxy"

CADDY_OK=false
CADDY_CONFIG_OK=false
APP_DIR_OK=false
ENDPOINTS_OK=true

systemctl is-active --quiet caddy && CADDY_OK=true

caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1 \
    && CADDY_CONFIG_OK=true

[ -d "$APP_DIR" ] && APP_DIR_OK=true

for endpoint in "${ENDPOINTS[@]}"; do
    IFS="|" read -r DOMAIN HOST_PORT SERVICE CONTAINER_PORT <<< "$endpoint"

    if ! grep -Fq "$DOMAIN {" "$CADDYFILE" \
        || ! grep -Fq "reverse_proxy 127.0.0.1:$HOST_PORT" "$CADDYFILE"; then
        ENDPOINTS_OK=false
    fi
done

log ""

$CADDY_OK \
    && log "  Service Caddy ............ OK" \
    || log_error "Service Caddy ............ ERREUR"

$CADDY_CONFIG_OK \
    && log "  Configuration Caddy ...... OK" \
    || log_error "Configuration Caddy ...... ERREUR"

$APP_DIR_OK \
    && log "  Dossier application ...... OK ($APP_DIR)" \
    || log_error "Dossier application ...... ERREUR"

$ENDPOINTS_OK \
    && log "  Endpoints Caddy .......... OK" \
    || log_error "Endpoints Caddy .......... ERREUR"

log ""
log_info "Endpoints configurés :"

for endpoint in "${ENDPOINTS[@]}"; do
    IFS="|" read -r DOMAIN HOST_PORT SERVICE CONTAINER_PORT <<< "$endpoint"
    log "  https://$DOMAIN -> 127.0.0.1:$HOST_PORT -> $SERVICE:$CONTAINER_PORT"
done

log ""

if ! $CADDY_OK || ! $CADDY_CONFIG_OK || ! $APP_DIR_OK || ! $ENDPOINTS_OK; then
    log_error "La configuration reverse proxy n'est pas complètement fonctionnelle."
    log_info "Consultez les erreurs ci-dessus avant de poursuivre."
    exit 1
fi
