#!/usr/bin/env bash

## ============================================================================
## Librairie d'interactions utilisateur
##
## Les fonctions acceptent désormais une clé de configuration facultative.
##
## Exemple :
##   ADMIN_USER=$(ask_input "Utilisateur admin" "admin" "ADMIN_USER")
##
## Si ADMIN_USER existe dans le fichier de configuration :
## - sa valeur est utilisée automatiquement.
##
## En mode --non-interactive :
## - aucune saisie n'est demandée ;
## - une valeur absente sans défaut provoque une erreur.
## ============================================================================


##
# Convertit une valeur de configuration en booléen.
##
parse_boolean() {
    local value="${1,,}"

    case "$value" in
        1|true|yes|y|on)
            return 0
            ;;
        0|false|no|n|off)
            return 1
            ;;
        *)
            return 2
            ;;
    esac
}


##
# Demande une valeur texte.
#
# Usage :
#   ask_input "Prompt" "default" "CONFIG_KEY"
##
ask_input() {
    local prompt="$1"
    local default="${2:-}"
    local config_key="${3:-}"
    local value=""

    if [ -n "$config_key" ] && config_has "$config_key"; then
        value="$(config_get "$config_key")"
        log_info "$prompt : valeur chargée depuis la configuration."
        printf '%s\n' "$value"
        return 0
    fi

    if $NON_INTERACTIVE; then
        if [ -n "$default" ]; then
            printf '%s\n' "$default"
            return 0
        fi

        log_error "Valeur obligatoire absente : ${config_key:-$prompt}"
        return 1
    fi

    read -r -p "$prompt [$default]: " value
    printf '%s\n' "${value:-$default}"
}


##
# Confirmation Y/N.
#
# Usage :
#   confirm "Activer ?" "FEATURE_ENABLED" "false"
##
confirm() {
    local prompt="$1"
    local config_key="${2:-}"
    local default="${3:-false}"
    local choice
    local configured

    if [ -n "$config_key" ] && config_has "$config_key"; then
        configured="$(config_get "$config_key")"

        if parse_boolean "$configured"; then
            log_info "$prompt : oui (configuration)"
            return 0
        fi

        case $? in
            1)
                log_info "$prompt : non (configuration)"
                return 1
                ;;
            *)
                log_error "Valeur booléenne invalide pour $config_key : $configured"
                return 2
                ;;
        esac
    fi

    if $NON_INTERACTIVE; then
        parse_boolean "$default"
        return $?
    fi

    read -r -p "$prompt (y/N): " choice

    case "$choice" in
        y|Y)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


##
# Confirmation stricte, sans valeur par défaut implicite en unattended.
##
confirm_required() {
    local prompt="$1"
    local config_key="$2"

    if config_has "$config_key"; then
        confirm "$prompt" "$config_key"
        return $?
    fi

    if $NON_INTERACTIVE; then
        log_error "Décision obligatoire absente : $config_key"
        return 2
    fi

    confirm "$prompt"
}
