#!/usr/bin/env bash
## Étape 50 - Snapshot fournisseur
##
## Le cœur du framework expose une interface stable.
## Chaque fournisseur possède son propre adaptateur dans providers/.
## "manual" permet de conserver un workflow fonctionnel tant qu'aucun
## adaptateur API n'est installé pour le fournisseur concerné.

log_step "Configuration du snapshot VPS fournisseur"

PROVIDER_CONFIG="/etc/server-setup/backup/provider.conf"
PROVIDER_NAME="$(ask_input "Provider snapshot (manual/ovh/ionos)" "manual")"

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

install -m 700 -o root -g root \
    "$PROVIDER_SOURCE" \
    "/usr/local/lib/server-setup/provider-snapshot.sh"

cat > "$PROVIDER_CONFIG" <<EOF
PROVIDER_NAME="$PROVIDER_NAME"
EOF
chmod 600 "$PROVIDER_CONFIG"

case "$PROVIDER_NAME" in
    manual)
        log_warn "Snapshot provider en mode manuel."
        log_info "Le timer journalisera l'action à réaliser dans le panel fournisseur."
        ;;
    ovh|ionos)
        log_warn "L'adaptateur '$PROVIDER_NAME' est un point d'intégration sécurisé."
        log_info "Il refuse toute action tant que les paramètres/API du fournisseur ne sont pas implémentés et validés."
        ;;
esac
