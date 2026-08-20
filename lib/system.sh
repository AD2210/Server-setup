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

wait_for_apt() {
    local timeout="${1:-600}"
    local interval="${2:-5}"
    local elapsed=0
    local lock_file
    local apt_busy=false

    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [ "$timeout" -lt 1 ]; then
        log_error "APT_WAIT_TIMEOUT doit être un entier supérieur à zéro : $timeout"
        return 1
    fi

    if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 1 ]; then
        log_error "APT_WAIT_INTERVAL doit être un entier supérieur à zéro : $interval"
        return 1
    fi

    log_step "Vérification de la disponibilité APT"

    while true; do
        apt_busy=false

        # Why: le verrou est la source réelle du conflit, même si le processus
        # APT n'est plus identifié sous le nom attendu.
        for lock_file in \
            /var/lib/dpkg/lock-frontend \
            /var/lib/dpkg/lock \
            /var/cache/apt/archives/lock; do
            if [ -e "$lock_file" ] && command_exists fuser \
                && fuser -s "$lock_file" 2>/dev/null; then
                apt_busy=true
                break
            fi
        done

        if ! $apt_busy && ! {
            pgrep -x apt >/dev/null 2>&1 ||
            pgrep -x apt-get >/dev/null 2>&1 ||
            pgrep -x dpkg >/dev/null 2>&1 ||
            pgrep -f '(^|/)unattended-upgrade( |$)' >/dev/null 2>&1;
        }; then
            log_info "APT est disponible."
            return 0
        fi

        if [ "$elapsed" -ge "$timeout" ]; then
            log_error "APT est toujours occupé après ${timeout}s."
            log_info "Vérifiez : systemctl status apt-daily-upgrade.service"
            return 1
        fi

        if [ "$elapsed" -eq 0 ]; then
            log_info "Une opération APT est déjà en cours, attente de sa fin..."
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}
