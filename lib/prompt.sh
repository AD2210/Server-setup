#!/usr/bin/env bash

## ============================================================================
## Librairie d'interactions utilisateur
## ============================================================================

ask() {
    local prompt="$1"
    local choice

    read -r -p "$prompt (y/n): " choice

    case "$choice" in
        y|Y) return 0 ;;
        *)   return 1 ;;
    esac
}

ask_input() {
    local prompt="$1"
    local default="${2:-}"
    local value

    read -r -p "$prompt [$default]: " value
    printf '%s\n' "${value:-$default}"
}

confirm() {
    local prompt="$1"
    local choice

    read -r -p "$prompt (y/N): " choice

    case "$choice" in
        y|Y) return 0 ;;
        *)   return 1 ;;
    esac
}
