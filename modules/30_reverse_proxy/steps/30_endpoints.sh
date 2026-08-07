#!/usr/bin/env bash

## ============================================================================
## Étape 30 - Saisie et validation des endpoints
##
## Un endpoint contient :
## - domaine public
## - port publié uniquement sur 127.0.0.1
## - nom du service Docker
## - port HTTP interne du conteneur
## ============================================================================

log_step "Définition de l'application et de ses endpoints"

domain_exists_in_caddy() {
    local domain="$1"

    awk -v domain="$domain" '
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (index(line, domain " {") == 1 || line == domain "{") {
                found=1
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$CADDYFILE"
}

port_used_in_session() {
    local candidate="$1"
    local endpoint d p s t

    for endpoint in "${ENDPOINTS[@]}"; do
        IFS="|" read -r d p s t <<< "$endpoint"

        if [ "$p" = "$candidate" ]; then
            return 0
        fi
    done

    return 1
}

domain_used_in_session() {
    local candidate="$1"
    local endpoint d p s t

    for endpoint in "${ENDPOINTS[@]}"; do
        IFS="|" read -r d p s t <<< "$endpoint"

        if [ "$d" = "$candidate" ]; then
            return 0
        fi
    done

    return 1
}

ask_host_port() {
    local port

    while true; do
        show_ports_info >&2
        port="$(ask_input "Port HTTP hôte utilisé par Caddy" "")"

        if ! [[ "$port" =~ ^[0-9]+$ ]] \
            || [ "$port" -lt 1 ] \
            || [ "$port" -gt 65535 ]; then
            log_error "Port invalide : $port"
            continue
        fi

        if get_used_ports | grep -qx "$port"; then
            log_error "Le port $port est déjà utilisé dans le Caddyfile."
            continue
        fi

        if port_used_in_session "$port"; then
            log_error "Le port $port est déjà utilisé dans cette configuration."
            continue
        fi

        printf '%s\n' "$port"
        return 0
    done
}

APP_NAME="$(ask_input "Nom de l'application" "app1")"

if [ -z "$APP_NAME" ] || ! [[ "$APP_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    log_error "Nom d'application invalide : $APP_NAME"
    exit 1
fi

APP_DIR="$APPS_DIR/$APP_NAME"

if [ -d "$APP_DIR" ]; then
    log_error "Le dossier de l'application existe déjà : $APP_DIR"
    exit 1
fi

if grep -Fq "# --- $APP_NAME ---" "$CADDYFILE"; then
    log_error "Une configuration Caddy existe déjà pour '$APP_NAME'."
    exit 1
fi

ENDPOINTS=()

while confirm "Ajouter un endpoint ?"; do
    DOMAIN="$(ask_input "Domaine" "example.com")"

    if ! [[ "$DOMAIN" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        log_error "Domaine invalide : $DOMAIN"
        continue
    fi

    if domain_exists_in_caddy "$DOMAIN"; then
        log_error "Le domaine '$DOMAIN' est déjà présent dans le Caddyfile."
        continue
    fi

    if domain_used_in_session "$DOMAIN"; then
        log_error "Le domaine '$DOMAIN' est déjà utilisé dans cette configuration."
        continue
    fi

    HOST_PORT="$(ask_host_port)"
    SERVICE="$(ask_input "Service Docker" "$APP_NAME")"
    CONTAINER_PORT="$(ask_input "Port HTTP interne du conteneur" "80")"

    if [ -z "$SERVICE" ] || ! [[ "$SERVICE" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
        log_error "Nom de service Docker invalide : $SERVICE"
        continue
    fi

    if ! [[ "$CONTAINER_PORT" =~ ^[0-9]+$ ]] \
        || [ "$CONTAINER_PORT" -lt 1 ] \
        || [ "$CONTAINER_PORT" -gt 65535 ]; then
        log_error "Port HTTP interne invalide : $CONTAINER_PORT"
        continue
    fi

    ENDPOINTS+=("$DOMAIN|$HOST_PORT|$SERVICE|$CONTAINER_PORT")
done

if [ "${#ENDPOINTS[@]}" -eq 0 ]; then
    log_error "Aucun endpoint défini."
    exit 1
fi
