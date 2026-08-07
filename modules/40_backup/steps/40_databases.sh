#!/usr/bin/env bash
## Étape 40 - Cibles PostgreSQL

log_step "Configuration des bases PostgreSQL"

get_compose_files_for_app() {
    find "$1" -maxdepth 2 -type f \( \
        -iname "compose*.yml" -o -iname "compose*.yaml" -o \
        -iname "docker-compose*.yml" -o -iname "docker-compose*.yaml" \
    \) 2>/dev/null | sort
}

add_database_target() {
    local name app compose service db_name_env db_user_env db_password_env file detected

    name="$(ask_input "Nom unique de la cible DB" "app-db")"
    [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || {
        log_error "Nom de cible invalide."
        return 1
    }

    file="$BACKUP_TARGETS_DIR/$name.conf"
    [ ! -e "$file" ] || {
        log_error "La cible '$name' existe déjà."
        return 1
    }

    app="$(ask_input "Répertoire application" "/srv/apps/app1")"
    [ -d "$app" ] || {
        log_error "Répertoire introuvable : $app"
        return 1
    }

    detected="$(get_compose_files_for_app "$app")"
    if [ -n "$detected" ]; then
        log_info "Compose détectés :"
        while IFS= read -r line; do log "  $line"; done <<< "$detected"
    fi

    compose="$(ask_input "Fichier Compose" "compose.yaml")"
    [[ "$compose" = /* ]] || compose="$app/$compose"
    [ -f "$compose" ] || {
        log_error "Compose introuvable : $compose"
        return 1
    }

    service="$(ask_input "Service PostgreSQL" "database")"
    db_name_env="$(ask_input "Variable nom DB" "POSTGRES_DB")"
    db_user_env="$(ask_input "Variable utilisateur DB" "POSTGRES_USER")"
    db_password_env="$(ask_input "Variable mot de passe DB" "POSTGRES_PASSWORD")"

    cat > "$file" <<EOF
TARGET_NAME="$name"
APP_DIR="$app"
COMPOSE_FILE="$compose"
DB_SERVICE="$service"
DB_NAME_ENV="$db_name_env"
DB_USER_ENV="$db_user_env"
DB_PASSWORD_ENV="$db_password_env"
EOF
    chmod 600 "$file"
    log_info "Cible '$name' enregistrée."
}

if compgen -G "$BACKUP_TARGETS_DIR/*.conf" >/dev/null; then
    log_info "Cibles existantes :"
    for f in "$BACKUP_TARGETS_DIR"/*.conf; do log "  $(basename "$f" .conf)"; done
fi

while confirm "Ajouter une base PostgreSQL ?"; do
    add_database_target || log_warn "Cible ignorée."
done
