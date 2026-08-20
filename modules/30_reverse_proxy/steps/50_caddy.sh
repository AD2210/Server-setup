#!/usr/bin/env bash

## ============================================================================
## Étape 50 - Installation du socle Caddy
##
## Le module gère uniquement la configuration serveur.
## Les fichiers d'application sont déposés dans /etc/caddy/apps par la CD.
## ============================================================================

log_step "Installation de la configuration serveur Caddy"

CADDY_TEMPLATE="$PROJECT_DIR/config/Caddyfile.example"
CADDY_SNIPPETS_SOURCE="$PROJECT_DIR/config/snippets"
CADDY_APPS_SOURCE="$PROJECT_DIR/config/apps"

[ -r "$CADDY_TEMPLATE" ] || {
    log_error "Template Caddy introuvable : $CADDY_TEMPLATE"
    exit 1
}

[ -d "$CADDY_SNIPPETS_SOURCE" ] || {
    log_error "Snippets Caddy introuvables : $CADDY_SNIPPETS_SOURCE"
    exit 1
}

if [ ! -e "$CADDYFILE" ]; then
    install -m 644 -o root -g root "$CADDY_TEMPLATE" "$CADDYFILE"
    log_info "Caddyfile serveur installé : $CADDYFILE"
elif ! grep -Fq 'import apps/*.caddy' "$CADDYFILE"; then
    CADDY_MIGRATION_BACKUP="$CADDYFILE.migration.$(date +%Y%m%d-%H%M%S)"

    if ! cp -a "$CADDYFILE" "$CADDY_MIGRATION_BACKUP"; then
        log_error "Impossible de sauvegarder l'ancien Caddyfile avant migration."
        exit 1
    fi

    install -m 644 -o root -g root "$CADDY_TEMPLATE" "$CADDYFILE"
    log_warn "Ancien Caddyfile remplacé par le socle serveur."
    log_info "Sauvegarde de migration : $CADDY_MIGRATION_BACKUP"
else
    log_info "Caddyfile existant conservé : $CADDYFILE"
fi

for snippet in "$CADDY_SNIPPETS_SOURCE"/*.caddy; do
    [ -f "$snippet" ] || continue
    target="$CADDY_SNIPPETS_DIR/$(basename "$snippet")"

    if [ -e "$target" ]; then
        log_info "Snippet existant conservé : $target"
    else
        install -m 644 -o root -g root "$snippet" "$target"
        log_info "Snippet installé : $target"
    fi
done

for app_file in "$CADDY_APPS_SOURCE"/*.caddy; do
    [ -f "$app_file" ] || continue
    target="$CADDY_APPS_DIR/$(basename "$app_file")"

    if [ ! -e "$target" ]; then
        install -m 644 -o root -g root "$app_file" "$target"
        log_info "Fichier d'attente applicatif installé : $target"
    fi
done

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

if ! caddy fmt --overwrite "$CADDYFILE" >/dev/null 2>&1; then
    log_error "Impossible de formater le Caddyfile."
    exit 1
fi

if ! caddy validate --config "$CADDYFILE" --adapter caddyfile >"$TMP_CADDY" 2>&1; then
    log_error "La configuration Caddy est invalide."
    cat "$TMP_CADDY" >&2
    cp -a "$CADDY_BACKUP" "$CADDYFILE"
    exit 1
fi

if ! systemctl reload caddy >"$TMP_CADDY" 2>&1; then
    log_error "Le rechargement de Caddy a échoué."
    cat "$TMP_CADDY" >&2
    cp -a "$CADDY_BACKUP" "$CADDYFILE"

    if ! systemctl restart caddy >/dev/null 2>&1; then
        log_error "Caddy ne redémarre pas après rollback."
        exit 1
    fi

    log_info "Configuration Caddy précédente restaurée."
    exit 1
fi

log_info "Configuration serveur Caddy validée et rechargée."
