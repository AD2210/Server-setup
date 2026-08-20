#!/usr/bin/env bash

## ============================================================================
## Étape 30 - Installation et configuration de Vector
## ============================================================================

log_step "Installation de Vector"

if ! command_exists vector; then
    if ! run_quiet "Impossible d'ajouter le dépôt APT Vector." \
        bash -o pipefail -c 'curl -L https://setup.vector.dev | bash'; then
        exit 1
    fi

    wait_for_apt "$(config_get APT_WAIT_TIMEOUT 600)" "$(config_get APT_WAIT_INTERVAL 5)"
    run_quiet "Impossible d'installer Vector." apt-get install -y vector || exit 1
else
    log_info "Vector est déjà installé."
fi

if [ ! -e "$VECTOR_ENV_FILE" ]; then
    install -m 600 -o root -g root \
        "$PROJECT_DIR/config/vector/vector.env.example" "$VECTOR_ENV_FILE"
else
    log_info "Configuration Vector existante conservée : $VECTOR_ENV_FILE"
fi

if [ ! -e "$VECTOR_CONFIG_FILE" ]; then
    install -m 644 -o root -g root \
        "$PROJECT_DIR/config/vector/vector.toml.example" "$VECTOR_CONFIG_FILE"
else
    log_info "Configuration Vector existante conservée : $VECTOR_CONFIG_FILE"
fi

if id vector >/dev/null 2>&1; then
    usermod -aG docker vector 2>/dev/null || true
    usermod -aG systemd-journal vector 2>/dev/null || true
fi

VECTOR_SYSTEMD_DROPIN_DIR="/etc/systemd/system/vector.service.d"
install -d -m 755 -o root -g root "$VECTOR_SYSTEMD_DROPIN_DIR"
cat > "$VECTOR_SYSTEMD_DROPIN_DIR/server-setup.conf" <<EOF
[Service]
EnvironmentFile=$VECTOR_ENV_FILE
EOF
systemctl daemon-reload

set -a
# shellcheck disable=SC1090
source "$VECTOR_ENV_FILE"
set +a

if grep -q 'CHANGE_ME' "$VECTOR_ENV_FILE"; then
    systemctl disable --now vector >/dev/null 2>&1 || true
    log_warn "Vector est installé mais désactivé : renseignez $VECTOR_ENV_FILE."
    log_info "Les endpoints sont des placeholders TODO jusqu'à la finalisation de l'API centrale."
else
    systemctl enable --now vector
fi

if ! run_quiet "La configuration Vector est invalide." vector validate "$VECTOR_CONFIG_FILE"; then
    exit 1
fi
