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
