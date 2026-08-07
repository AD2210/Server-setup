#!/usr/bin/env bash

## ============================================================================
## Librairie de logs
##
## Convention :
## - log() écrit sur stdout pour les sorties neutres.
## - les sorties structurées écrivent sur stderr afin de ne pas polluer
##   les substitutions de commande : VALUE=$(fonction).
## ============================================================================

log() {
    echo -e "$1"
}

log_module() {
    echo -e "\e[1;96m[RUN]\e[0m $1" >&2
}

log_step() {
    echo -e "\e[37m[STEP]\e[0m $1" >&2
}

log_success() {
    echo -e "\e[1;92m[SUCCESS]\e[0m $1" >&2
}

log_info() {
    echo -e "\e[94m[INFO]\e[0m $1" >&2
}

log_warn() {
    echo -e "\e[1;93m[WARN]\e[0m $1" >&2
}

log_error() {
    echo -e "\e[1;91m[ERROR]\e[0m $1" >&2
}
