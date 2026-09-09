#!/usr/bin/env bash

## ============================================================================
## Librairie d'utilitaires génériques
## ============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

load_env() {
    local env_file="${1:-}"

    if [ -z "$env_file" ] || [ ! -f "$env_file" ]; then
        return 0
    fi

    # shellcheck disable=SC1090
    source "$env_file"
}

run_quiet() {
    local error_message="$1"
    shift

    # Why: une mise à jour automatique peut démarrer entre deux modules, même
    # si le préflight initial avait trouvé APT disponible.
    case "${1:-}" in
        apt | apt-get | apt-cache | dpkg)
            if declare -F wait_for_apt >/dev/null 2>&1; then
                wait_for_apt \
                    "$(config_get APT_WAIT_TIMEOUT 600)" \
                    "$(config_get APT_WAIT_INTERVAL 5)" ||
                    return 1
            fi
            ;;
    esac

    local error_file
    error_file="$(mktemp)"

    if "$@" >/dev/null 2>"$error_file"; then
        rm -f "$error_file"
        return 0
    fi

    log_error "$error_message"

    if [ -s "$error_file" ]; then
        log_info "Détail de l'erreur :"
        cat "$error_file" >&2
    fi

    rm -f "$error_file"
    return 1
}

run_quiet_timeout() {
    local timeout_seconds="$1"
    local error_message="$2"
    shift 2

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [ "$timeout_seconds" -lt 1 ]; then
        log_error "Timeout invalide : $timeout_seconds"
        return 1
    fi

    if ! command_exists timeout; then
        log_error "La commande timeout est requise."
        return 1
    fi

    # Why: une mise à jour automatique peut démarrer entre deux modules, même
    # si le préflight initial avait trouvé APT disponible.
    case "${1:-}" in
        apt | apt-get | apt-cache | dpkg)
            if declare -F wait_for_apt >/dev/null 2>&1; then
                wait_for_apt \
                    "$(config_get APT_WAIT_TIMEOUT 600)" \
                    "$(config_get APT_WAIT_INTERVAL 5)" ||
                    return 1
            fi
            ;;
    esac

    local error_file
    local exit_status
    error_file="$(mktemp)"

    if timeout -v --kill-after=10s "${timeout_seconds}s" "$@" >/dev/null 2>"$error_file"; then
        rm -f "$error_file"
        return 0
    fi

    exit_status=$?
    log_error "$error_message"

    if [ "$exit_status" -eq 124 ] || [ "$exit_status" -eq 137 ] || grep -q '^timeout: ' "$error_file"; then
        log_error "Commande interrompue après ${timeout_seconds}s."
    fi

    if [ -s "$error_file" ]; then
        log_info "Détail de l'erreur :"
        cat "$error_file" >&2
    fi

    rm -f "$error_file"
    return 1
}

require_project_structure() {
    local project_dir="$1"
    local required_paths=(
        "bin"
        "lib"
        "modules"
        "config"
        "lib/log.sh"
        "lib/prompt.sh"
        "lib/utils.sh"
        "lib/system.sh"
    )

    local path

    log_step "Vérification de l'arborescence du projet"

    for path in "${required_paths[@]}"; do
        if [ ! -e "$project_dir/$path" ]; then
            log_error "Élément requis introuvable : $path"
            log_info "Projet détecté : $project_dir"
            exit 1
        fi
    done

    log_info "Arborescence du projet valide."
}
