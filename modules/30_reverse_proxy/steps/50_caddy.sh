#!/usr/bin/env bash

## ============================================================================
## Étape 50 - Génération et rechargement du Caddyfile
##
## - sauvegarde le Caddyfile
## - travaille dans un fichier temporaire
## - formate et valide la configuration
## - conserve les permissions du Caddyfile original
## - rollback si le reload échoue
## ============================================================================

log_step "Mise à jour du Caddyfile"

CADDY_BACKUP="$CADDYFILE.bak.$(date +%Y%m%d-%H%M%S)"
TMP_CADDY="$(mktemp)"

cleanup_caddy_tmp() {
    rm -f "$TMP_CADDY"
}

trap cleanup_caddy_tmp EXIT

if ! cp -a "$CADDYFILE" "$CADDY_BACKUP"; then
    log_error "Impossible de sauvegarder le Caddyfile."
    exit 1
fi

log_info "Sauvegarde Caddy créée : $CADDY_BACKUP"

if ! cp "$CADDYFILE" "$TMP_CADDY"; then
    log_error "Impossible de préparer le Caddyfile temporaire."
    exit 1
fi

{
    echo ""
    echo "# --- $APP_NAME ---"

    for endpoint in "${ENDPOINTS[@]}"; do
        IFS="|" read -r DOMAIN HOST_PORT SERVICE CONTAINER_PORT <<< "$endpoint"

        cat <<EOF
$DOMAIN {
    reverse_proxy 127.0.0.1:$HOST_PORT
}

EOF
    done

    echo "# --- END $APP_NAME ---"
} >> "$TMP_CADDY"

run_quiet \
    "Impossible de formater le nouveau Caddyfile." \
    caddy fmt --overwrite "$TMP_CADDY" \
    || exit 1

run_quiet \
    "La nouvelle configuration Caddy est invalide." \
    caddy validate --config "$TMP_CADDY" --adapter caddyfile \
    || exit 1

# Écriture dans le fichier existant :
# on conserve ainsi son propriétaire et ses permissions.
if ! cat "$TMP_CADDY" > "$CADDYFILE"; then
    log_error "Impossible de mettre à jour le Caddyfile."
    exit 1
fi

if ! run_quiet "Le rechargement de Caddy a échoué." systemctl reload caddy; then
    log_warn "Rollback du Caddyfile."

    if ! cat "$CADDY_BACKUP" > "$CADDYFILE"; then
        log_error "Impossible de restaurer le Caddyfile."
        exit 1
    fi

    if ! run_quiet \
        "Caddy ne redémarre pas après rollback." \
        systemctl restart caddy; then
        log_error "Intervention manuelle requise sur le service Caddy."
        exit 1
    fi

    log_info "Configuration Caddy précédente restaurée."
    exit 1
fi

log_info "Caddyfile validé et rechargé."
