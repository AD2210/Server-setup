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

    # Versions Ubuntu LTS supportées par Server Setup.
    local supported_versions=(
        "22.04"
        "24.04"
        "26.04"
    )

    local version_supported=false
    local version

    for version in "${supported_versions[@]}"; do
        if [ "${VERSION_ID:-}" = "$version" ]; then
            version_supported=true
            break
        fi
    done

    if [ "$version_supported" != true ]; then
        log_error "Version Ubuntu non supportée : ${VERSION_ID:-inconnue}"
        log_info "Versions LTS supportées : ${supported_versions[*]}"
        exit 1
    fi

    export VERSION_ID VERSION_CODENAME

    log_info "Ubuntu ${VERSION_ID} LTS détecté."
}
