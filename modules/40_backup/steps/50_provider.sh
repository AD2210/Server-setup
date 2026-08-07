#!/usr/bin/env bash

## ============================================================================
## Étape 50 - Provider snapshot VPS
##
## OVHcloud :
## - utilise l'API VPS historique via le SDK officiel python-ovh
## - stocke les credentials sous /etc/server-setup/backup/providers/
## - utilise un virtualenv dédié sous /var/lib/server-setup/
## - valide les credentials et le VPS avant activation
##
## Important :
## OVH VPS ne conserve qu'un snapshot manuel à la fois.
## La rotation supprime donc le snapshot existant avant d'en créer un nouveau.
## ============================================================================

log_step "Configuration du snapshot VPS fournisseur"

PROVIDER_CONFIG_DIR="/etc/server-setup/backup/providers"
PROVIDER_RUNTIME_DIR="/usr/local/lib/server-setup"
PROVIDER_STATE_DIR="/var/lib/server-setup/providers"
OVH_VENV="$PROVIDER_STATE_DIR/ovh-venv"
OVH_CONFIG="$PROVIDER_CONFIG_DIR/ovh.conf"
PROVIDER_CONFIG="/etc/server-setup/backup/provider.conf"

install -d -m 700 -o root -g root "$PROVIDER_CONFIG_DIR"
install -d -m 755 -o root -g root "$PROVIDER_RUNTIME_DIR"
install -d -m 700 -o root -g root "$PROVIDER_STATE_DIR"

PROVIDER_NAME="$(ask_input "Provider snapshot (manual/ovh/ionos)" "ovh")"

case "$PROVIDER_NAME" in
    manual|ovh|ionos) ;;
    *)
        log_error "Provider inconnu : $PROVIDER_NAME"
        exit 1
        ;;
esac

PROVIDER_SOURCE="$MODULE_DIR/providers/$PROVIDER_NAME.sh"

[ -f "$PROVIDER_SOURCE" ] || {
    log_error "Adaptateur provider absent : $PROVIDER_SOURCE"
    exit 1
}

if [ "$PROVIDER_NAME" = "ovh" ]; then
    OVH_PY_SOURCE="$MODULE_DIR/providers/ovh.py"

    [ -f "$OVH_PY_SOURCE" ] || {
        log_error "Client OVH absent : $OVH_PY_SOURCE"
        exit 1
    }

    log_info "Préparation du SDK officiel OVHcloud."

    if [ ! -x "$OVH_VENV/bin/python" ]; then
        run_quiet \
            "Impossible de créer le virtualenv OVH." \
            python3 -m venv "$OVH_VENV" \
            || exit 1
    fi

    run_quiet \
        "Impossible d'installer le SDK python-ovh." \
        "$OVH_VENV/bin/pip" install --disable-pip-version-check \
            "ovh>=1.2,<2" \
        || exit 1

    install -m 700 -o root -g root \
        "$OVH_PY_SOURCE" \
        "$PROVIDER_RUNTIME_DIR/ovh-provider.py"

    log ""
    log_info "Credentials OVHcloud nécessaires."
    log_info "Créez un token script OVHcloud Europe avec les droits minimum suivants :"
    log ""
    log "  GET    /vps"
    log "  GET    /vps/*"
    log "  POST   /vps/*/createSnapshot"
    log "  DELETE /vps/*/snapshot"
    log ""
    log_info "Création des credentials : https://eu.api.ovh.com/createToken/"
    log ""

    OVH_ENDPOINT="$(ask_input "Endpoint OVH" "ovh-eu")"
    OVH_APPLICATION_KEY="$(ask_input "Application Key" "")"

    read -r -s -p "Application Secret: " OVH_APPLICATION_SECRET
    echo ""

    OVH_CONSUMER_KEY="$(ask_input "Consumer Key" "")"

    if [ -z "$OVH_APPLICATION_KEY" ] \
        || [ -z "$OVH_APPLICATION_SECRET" ] \
        || [ -z "$OVH_CONSUMER_KEY" ]; then

        log_error "Les credentials OVH sont incomplets."
        exit 1
    fi

    cat > "$OVH_CONFIG" <<EOF
OVH_ENDPOINT="$OVH_ENDPOINT"
OVH_APPLICATION_KEY="$OVH_APPLICATION_KEY"
OVH_APPLICATION_SECRET="$OVH_APPLICATION_SECRET"
OVH_CONSUMER_KEY="$OVH_CONSUMER_KEY"
EOF

    chmod 600 "$OVH_CONFIG"

    log_info "Validation des credentials OVHcloud."

    if ! "$OVH_VENV/bin/python" "$PROVIDER_RUNTIME_DIR/ovh-provider.py" \
        --config "$OVH_CONFIG" test >/dev/null 2>&1; then

        log_error "Impossible de s'authentifier auprès de l'API OVHcloud."
        log_info "Vérifiez les clés et leurs permissions."
        exit 1
    fi

    VPS_LIST="$(
        "$OVH_VENV/bin/python" "$PROVIDER_RUNTIME_DIR/ovh-provider.py" \
            --config "$OVH_CONFIG" list-vps 2>/dev/null
    )"

    if [ -z "$VPS_LIST" ]; then
        log_error "Aucun VPS accessible avec ces credentials."
        exit 1
    fi

    log_info "VPS accessibles :"
    while IFS= read -r vps; do
        log "  $vps"
    done <<< "$VPS_LIST"

    OVH_SERVICE_NAME="$(ask_input "Service OVH du VPS" "$(head -n1 <<< "$VPS_LIST")")"

    if ! grep -qxF "$OVH_SERVICE_NAME" <<< "$VPS_LIST"; then
        log_error "Le VPS '$OVH_SERVICE_NAME' n'est pas accessible avec ce token."
        exit 1
    fi

    cat >> "$OVH_CONFIG" <<EOF
OVH_SERVICE_NAME="$OVH_SERVICE_NAME"
EOF

    chmod 600 "$OVH_CONFIG"

    log_info "VPS OVH sélectionné : $OVH_SERVICE_NAME"
    log_warn "OVH VPS conserve un seul snapshot manuel à la fois."
    log_info "À chaque rotation, l'ancien snapshot sera supprimé avant création du nouveau."
fi

install -m 700 -o root -g root \
    "$PROVIDER_SOURCE" \
    "$PROVIDER_RUNTIME_DIR/provider-snapshot.sh"

cat > "$PROVIDER_CONFIG" <<EOF
PROVIDER_NAME="$PROVIDER_NAME"
EOF
chmod 600 "$PROVIDER_CONFIG"

case "$PROVIDER_NAME" in
    manual)
        log_warn "Snapshot provider configuré en mode manuel."
        ;;
    ovh)
        log_info "Provider OVHcloud configuré."
        ;;
    ionos)
        log_warn "Adaptateur IONOS non configuré."
        ;;
esac
