#!/usr/bin/env bash
log_step "Configuration des snapshots serveur"

FILES_BACKUP_ENABLED=false
PROVIDER_BACKUP_ENABLED=false
PROVIDER_NAME="none"

log "  none     : aucun snapshot serveur"
log "  logical  : snapshot logique uniquement"
log "  provider : snapshot fournisseur uniquement"
log "  both     : snapshot logique + fournisseur"

SNAPSHOT_MODE="$(ask_input "Mode snapshot" "logical" "SNAPSHOT_MODE")"

case "$SNAPSHOT_MODE" in
    none) ;;
    logical) FILES_BACKUP_ENABLED=true ;;
    provider) PROVIDER_BACKUP_ENABLED=true ;;
    both)
        FILES_BACKUP_ENABLED=true
        PROVIDER_BACKUP_ENABLED=true
        ;;
    *)
        log_error "Mode snapshot invalide : $SNAPSHOT_MODE"
        exit 1
        ;;
esac

if $PROVIDER_BACKUP_ENABLED; then
    PROVIDER_CONFIG_DIR="/etc/server-setup/backup/providers"
    PROVIDER_RUNTIME_DIR="/usr/local/lib/server-setup"
    PROVIDER_STATE_DIR="/var/lib/server-setup/providers"
    PROVIDER_CONFIG="/etc/server-setup/backup/provider.conf"

    install -d -m 700 -o root -g root "$PROVIDER_CONFIG_DIR"
    install -d -m 755 -o root -g root "$PROVIDER_RUNTIME_DIR"
    install -d -m 700 -o root -g root "$PROVIDER_STATE_DIR"

    PROVIDER_NAME="$(ask_input "Provider snapshot (manual/ovh/ionos)" "manual" "PROVIDER_NAME")"

    case "$PROVIDER_NAME" in
        manual | ovh | ionos) ;;
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
        OVH_VENV="$PROVIDER_STATE_DIR/ovh-venv"
        OVH_CONFIG="$PROVIDER_CONFIG_DIR/ovh.conf"

        [ -f "$MODULE_DIR/providers/ovh.py" ] || {
            log_error "Client OVH absent."
            exit 1
        }

        [ -x "$OVH_VENV/bin/python" ] || run_quiet "Impossible de créer le virtualenv OVH." python3 -m venv "$OVH_VENV" || exit 1

        run_quiet "Impossible d'installer le SDK python-ovh." "$OVH_VENV/bin/pip" install --disable-pip-version-check "ovh>=1.2,<2" || exit 1

        install -m 700 -o root -g root "$MODULE_DIR/providers/ovh.py" "$PROVIDER_RUNTIME_DIR/ovh-provider.py"

        KEEP_OVH_CONFIG=false
        if [ -r "$OVH_CONFIG" ]; then
            if $NON_INTERACTIVE; then
                if confirm_required "Conserver la configuration OVH existante ?" "OVH_KEEP_EXISTING"; then
                    KEEP_OVH_CONFIG=true
                elif [ "$?" -eq 2 ]; then
                    exit 1
                fi
            elif confirm "Conserver la configuration OVH existante ?"; then
                KEEP_OVH_CONFIG=true
            fi
        fi

        if $KEEP_OVH_CONFIG; then
            log_info "Configuration OVH conservée."
        else
            OVH_ENDPOINT="$(ask_input "Endpoint OVH" "ovh-eu" "OVH_ENDPOINT")"
            OVH_APPLICATION_KEY="$(ask_input "Application Key" "" "OVH_APPLICATION_KEY")"

            if config_has "OVH_APPLICATION_SECRET"; then
                OVH_APPLICATION_SECRET="$(config_get OVH_APPLICATION_SECRET)"
            elif $NON_INTERACTIVE; then
                log_error "OVH_APPLICATION_SECRET absent en mode non interactif."
                exit 1
            else
                read -r -s -p "Application Secret: " OVH_APPLICATION_SECRET
                echo ""
            fi

            OVH_CONSUMER_KEY="$(ask_input "Consumer Key" "" "OVH_CONSUMER_KEY")"

            [ -n "$OVH_APPLICATION_KEY" ] && [ -n "$OVH_APPLICATION_SECRET" ] && [ -n "$OVH_CONSUMER_KEY" ] || {
                log_error "Credentials OVH incomplets."
                exit 1
            }

            cat >"$OVH_CONFIG" <<EOF
OVH_ENDPOINT="$OVH_ENDPOINT"
OVH_APPLICATION_KEY="$OVH_APPLICATION_KEY"
OVH_APPLICATION_SECRET="$OVH_APPLICATION_SECRET"
OVH_CONSUMER_KEY="$OVH_CONSUMER_KEY"
EOF
            chmod 600 "$OVH_CONFIG"

            "$OVH_VENV/bin/python" "$PROVIDER_RUNTIME_DIR/ovh-provider.py" --config "$OVH_CONFIG" test >/dev/null 2>&1 || {
                log_error "Authentification OVH impossible."
                exit 1
            }

            VPS_LIST="$("$OVH_VENV/bin/python" "$PROVIDER_RUNTIME_DIR/ovh-provider.py" --config "$OVH_CONFIG" list-vps 2>/dev/null)"

            [ -n "$VPS_LIST" ] || {
                log_error "Aucun VPS accessible."
                exit 1
            }

            log_info "VPS accessibles :"
            while IFS= read -r vps; do log "  $vps"; done <<<"$VPS_LIST"

            OVH_SERVICE_NAME="$(ask_input "Service OVH du VPS" "$(head -n1 <<<"$VPS_LIST")" "OVH_SERVICE_NAME")"
            grep -qxF "$OVH_SERVICE_NAME" <<<"$VPS_LIST" || {
                log_error "VPS OVH inaccessible avec ce token."
                exit 1
            }

            echo "OVH_SERVICE_NAME="$OVH_SERVICE_NAME"" >>"$OVH_CONFIG"
        fi
    fi

    install -m 700 -o root -g root "$PROVIDER_SOURCE" "$PROVIDER_RUNTIME_DIR/provider-snapshot.sh"

    echo "PROVIDER_NAME="$PROVIDER_NAME"" >"$PROVIDER_CONFIG"
    chmod 600 "$PROVIDER_CONFIG"
fi

$FILES_BACKUP_ENABLED && log_info "Snapshot logique activé." || log_info "Snapshot logique désactivé."
$PROVIDER_BACKUP_ENABLED && log_info "Snapshot provider activé : $PROVIDER_NAME" || log_info "Snapshot fournisseur désactivé."
