#!/usr/bin/env bash

## ============================================================================
## Étape 20 - Inventaire des ports existants
##
## Les ports HTTP sont lus dans le Caddyfile.
## Les ports DB sont lus à titre indicatif dans les fichiers .env* existants.
## ============================================================================

get_used_ports() {
    grep -E 'reverse_proxy[[:space:]]+127\.0\.0\.1:[0-9]+' "$CADDYFILE" 2>/dev/null \
        | grep -oE '127\.0\.0\.1:[0-9]+' \
        | cut -d: -f2 \
        | sort -n \
        | uniq
}

get_env_files() {
    find "$APPS_DIR" \
        -type f \
        -name ".env*" \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        2>/dev/null
}

get_db_ports_with_app() {
    local file app line port

    while IFS= read -r file; do
        app="$(basename "$(dirname "$file")")"

        while IFS= read -r line; do
            port="${line#*=}"
            port="${port%%[[:space:]#]*}"

            if [[ "$port" =~ ^[0-9]+$ ]]; then
                printf '%s -> %s\n' "$app" "$port"
            fi
        done < <(
            grep -Ei '^[[:space:]]*(DB_PORT|POSTGRES_PORT|MYSQL_PORT)[[:space:]]*=[[:space:]]*[0-9]+' \
                "$file" 2>/dev/null || true
        )
    done < <(get_env_files)
}

show_ports_info() {
    local ports

    ports="$(get_used_ports | tr '\n' ' ')"

    log_info "Ports HTTP déjà utilisés : ${ports:-aucun}"
    log "  Plages recommandées :"
    log "  - Frontend : 3000-3999"
    log "  - API      : 8000-8999"
    log "  - Divers   : 9000+"
}

show_db_ports_info() {
    local db_ports

    db_ports="$(get_db_ports_with_app)"

    log_info "Ports DB détectés dans les .env* existants :"

    if [ -n "$db_ports" ]; then
        while IFS= read -r line; do
            log "  $line"
        done <<< "$db_ports"
    else
        log "  Aucun port DB détecté."
    fi
}
