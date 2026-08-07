#!/usr/bin/env bash

## ============================================================================
## Librairie de contrôles système
## ============================================================================

require_root() {
    log_step "Vérification des privilèges administrateur"

    if [ "$EUID" -ne 0 ]; then
        log_error "Cette commande nécessite les privilèges administrateur."
        log_info "Relancez avec : sudo setup ${1:-<commande>}"
        exit 1
    fi

    log_info "Privilèges administrateur validés."
}

require_ubuntu_lts() {
    log_step "Vérification du système d'exploitation"

    if [ ! -r /etc/os-release ]; then
        log_error "Impossible d'identifier le système d'exploitation."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [ "${ID:-}" != "ubuntu" ]; then
        log_error "Distribution non supportée : ${ID:-inconnue}"
        log_info "Server Setup est prévu pour Ubuntu Server LTS."
        exit 1
    fi

    if [[ "${VERSION:-}" != *LTS* ]]; then
        log_error "Version Ubuntu non LTS détectée : ${VERSION_ID:-inconnue}"
        log_info "Server Setup est prévu uniquement pour Ubuntu Server LTS."
        exit 1
    fi

    export VERSION_ID VERSION_CODENAME
}
