#!/usr/bin/env bash
log_step "Configuration de GitHub Container Registry"

GHCR_REGISTRY="ghcr.io"

if $NON_INTERACTIVE; then
    if ! config_has "GHCR_ENABLED"; then
        log_error "Valeur obligatoire absente : GHCR_ENABLED"
        exit 1
    fi

    if confirm "Configurer GitHub Container Registry ?" "GHCR_ENABLED"; then
        GHCR_ENABLED=true
    else
        GHCR_ENABLED=false
    fi
else
    if confirm "Configurer GitHub Container Registry ?"; then
        GHCR_ENABLED=true
    else
        GHCR_ENABLED=false
    fi
fi

if ! $GHCR_ENABLED; then
    log_info "GitHub Container Registry désactivé."
else
    if declare -F config_has >/dev/null 2>&1 && config_has "GHCR_USERNAME"; then
        GHCR_USERNAME="$(config_get GHCR_USERNAME)"
    else
        GHCR_USERNAME="$(ask_input "Utilisateur GitHub / compte technique" "" "GHCR_USERNAME")"
    fi

    [ -n "$GHCR_USERNAME" ] || { log_error "Utilisateur GHCR manquant."; exit 1; }

    GHCR_TOKEN=""
    if declare -F config_has >/dev/null 2>&1 && config_has "GHCR_TOKEN"; then
        GHCR_TOKEN="$(config_get GHCR_TOKEN)"
    else
        read -r -s -p "Token GHCR (read:packages): " GHCR_TOKEN
        echo ""
    fi

    [ -n "$GHCR_TOKEN" ] || { log_error "Token GHCR manquant."; exit 1; }

    ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
    [ -d "$ADMIN_HOME" ] || { log_error "Home de '$ADMIN_USER' introuvable."; exit 1; }

    if ! printf '%s' "$GHCR_TOKEN" | sudo -u "$ADMIN_USER" HOME="$ADMIN_HOME"         docker login "$GHCR_REGISTRY" -u "$GHCR_USERNAME" --password-stdin >/dev/null 2>&1; then
        unset GHCR_TOKEN
        log_error "Authentification GHCR impossible."
        exit 1
    fi
    unset GHCR_TOKEN

    [ -f "$ADMIN_HOME/.docker/config.json" ] && {
        chown -R "$ADMIN_USER:$ADMIN_USER" "$ADMIN_HOME/.docker"
        chmod 700 "$ADMIN_HOME/.docker"
        chmod 600 "$ADMIN_HOME/.docker/config.json"
    }

    log_info "Authentification GHCR configurée pour '$ADMIN_USER'."
fi
