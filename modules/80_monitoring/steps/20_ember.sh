#!/usr/bin/env bash

## ============================================================================
## Étape 20 - Installation et initialisation d'Ember
## ============================================================================

log_step "Installation d'Ember"

if $NON_INTERACTIVE; then
    EMBER_INSTALL_TIMEOUT_DEFAULT=300
    EMBER_INIT_TIMEOUT_DEFAULT=60
else
    EMBER_INSTALL_TIMEOUT_DEFAULT=900
    EMBER_INIT_TIMEOUT_DEFAULT=120
fi

EMBER_INSTALL_TIMEOUT="$(config_get EMBER_INSTALL_TIMEOUT "$EMBER_INSTALL_TIMEOUT_DEFAULT")"
EMBER_INIT_TIMEOUT="$(config_get EMBER_INIT_TIMEOUT "$EMBER_INIT_TIMEOUT_DEFAULT")"

if command_exists ember; then
    log_info "Ember est déjà installé : $(ember version 2>/dev/null || true)"
else
    # Why: l'installateur officiel télécharge l'archive release et vérifie son
    # checksum SHA-256 avant d'installer le binaire dans /usr/local/bin.
    log_info "Téléchargement et exécution de l'installateur Ember."
    if ! run_quiet_timeout "$EMBER_INSTALL_TIMEOUT" "Impossible d'installer Ember." \
        bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/alexandre-daubois/ember/main/install.sh | sh' </dev/null; then
        exit 1
    fi
fi

log_info "Initialisation Ember avec l'API Caddy locale."
if ! run_quiet_timeout "$EMBER_INIT_TIMEOUT" "Ember ne peut pas initialiser la configuration Caddy." ember init </dev/null; then
    log_warn "Ember est installé, mais son initialisation Caddy doit être vérifiée manuellement."
else
    log_info "Ember a validé l'API Caddy et les métriques."
fi
