#!/usr/bin/env bash

## ============================================================================
## Étape 20 - Installation et initialisation d'Ember
## ============================================================================

log_step "Installation d'Ember"

if command_exists ember; then
    log_info "Ember est déjà installé : $(ember version 2>/dev/null || true)"
else
    # Why: l'installateur officiel télécharge l'archive release et vérifie son
    # checksum SHA-256 avant d'installer le binaire dans /usr/local/bin.
    if ! run_quiet "Impossible d'installer Ember." \
        bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/alexandre-daubois/ember/main/install.sh | sh'; then
        exit 1
    fi
fi

if ! run_quiet "Ember ne peut pas initialiser la configuration Caddy." ember init; then
    log_warn "Ember est installé, mais son initialisation Caddy doit être vérifiée manuellement."
else
    log_info "Ember a validé l'API Caddy et les métriques."
fi
