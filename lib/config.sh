#!/usr/bin/env bash

## ============================================================================
## Librairie de configuration
##
## Fournit :
## - chargement d'un fichier de configuration principal
## - chargement facultatif d'un fichier de secrets
## - lecture sécurisée de valeurs
## - détection du mode non interactif
##
## Les fichiers attendus utilisent une syntaxe shell simple :
##
##   KEY="value"
##   OTHER_KEY="true"
##
## Les fichiers ne doivent contenir aucune commande.
## ============================================================================

CONFIG_FILE=""
SECRETS_FILE=""
NON_INTERACTIVE=false

##
# Vérifie qu'un fichier de configuration ne contient que des affectations
# simples, commentaires ou lignes vides.
##
validate_config_file() {
    local file="$1"

    [ -f "$file" ] || {
        log_error "Fichier de configuration introuvable : $file"
        return 1
    }

    local invalid_lines
    invalid_lines="$(
        grep -nEv \
            '^[[:space:]]*($|#.*|[A-Za-z_][A-Za-z0-9_]*="([^"\\]|\\.)*"|[A-Za-z_][A-Za-z0-9_]*=[A-Za-z0-9._:/,@+%=-]+)[[:space:]]*$' \
            "$file" ||
            true
    )"

    if [ -n "$invalid_lines" ]; then
        log_error "Syntaxe non autorisée dans : $file"
        log_info "Seules les affectations KEY=value sont acceptées."
        log "$invalid_lines"
        return 1
    fi
}

##
# Charge un fichier de configuration validé.
##
load_config_file() {
    local file="$1"

    validate_config_file "$file" || return 1

    # shellcheck disable=SC1090
    source "$file"
}

##
# Initialisation globale de la configuration.
##
init_config() {
    local config_file="${1:-}"
    local secrets_file="${2:-}"

    if [ -n "$config_file" ]; then
        CONFIG_FILE="$config_file"
        log_step "Chargement de la configuration"
        load_config_file "$CONFIG_FILE" || exit 1
        log_info "Configuration chargée : $CONFIG_FILE"
    fi

    if [ -n "$secrets_file" ]; then
        SECRETS_FILE="$secrets_file"

        if [ ! -f "$SECRETS_FILE" ]; then
            log_error "Fichier de secrets introuvable : $SECRETS_FILE"
            exit 1
        fi

        local mode
        mode="$(stat -c '%a' "$SECRETS_FILE")"

        if [ "$mode" != "600" ] && [ "$mode" != "400" ]; then
            log_error "Permissions trop ouvertes sur le fichier de secrets : $mode"
            log_info "Utilisez : chmod 600 $SECRETS_FILE"
            exit 1
        fi

        load_config_file "$SECRETS_FILE" || exit 1
        log_info "Secrets chargés depuis un fichier protégé."
    fi
}

##
# Retourne la valeur d'une variable par son nom.
##
config_get() {
    local key="$1"
    local default="${2:-}"

    if [[ -v "$key" ]] && [ -n "${!key}" ]; then
        printf '%s\n' "${!key}"
    else
        printf '%s\n' "$default"
    fi
}

##
# Indique si une clé possède une valeur.
##
config_has() {
    local key="$1"
    [[ -v "$key" ]] && [ -n "${!key}" ]
}
