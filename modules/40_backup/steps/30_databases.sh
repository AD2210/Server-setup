#!/usr/bin/env bash
log_step "Configuration des sauvegardes PostgreSQL"

BACKUP_CONFIG_DIR="/etc/server-setup/backup"
BACKUP_TARGETS_DIR="$BACKUP_CONFIG_DIR/targets.d"
install -d -m 700 -o root -g root "$BACKUP_CONFIG_DIR" "$BACKUP_TARGETS_DIR"

DB_BACKUP_ENABLED=false

get_compose_files_for_app() {
    find "$1" -maxdepth 2 -type f \(         -iname "compose*.yml" -o -iname "compose*.yaml" -o         -iname "docker-compose*.yml" -o -iname "docker-compose*.yaml"     \) 2>/dev/null | sort
}

add_database_target() {
    local name app compose service db_name_env db_user_env db_password_env target_file detected

    name="$(ask_input "Nom unique de la cible DB" "app-db")"
    [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || { log_error "Nom de cible invalide : $name"; return 1; }

    target_file="$BACKUP_TARGETS_DIR/$name.conf"
    [ ! -e "$target_file" ] || { log_error "La cible '$name' existe déjà."; return 1; }

    app="$(ask_input "Répertoire de l'application" "/srv/apps/app1")"
    [ -d "$app" ] || { log_error "Répertoire introuvable : $app"; return 1; }

    detected="$(get_compose_files_for_app "$app")"
    if [ -n "$detected" ]; then
        log_info "Fichiers Compose détectés :"
        while IFS= read -r line; do log "  $line"; done <<< "$detected"
    fi

    compose="$(ask_input "Fichier Compose" "compose.yaml")"
    [[ "$compose" = /* ]] || compose="$app/$compose"
    [ -f "$compose" ] || { log_error "Compose introuvable : $compose"; return 1; }

    service="$(ask_input "Service PostgreSQL" "database")"
    db_name_env="$(ask_input "Variable nom DB" "POSTGRES_DB")"
    db_user_env="$(ask_input "Variable utilisateur DB" "POSTGRES_USER")"
    db_password_env="$(ask_input "Variable mot de passe DB" "POSTGRES_PASSWORD")"

    cat > "$target_file" <<EOF
TARGET_NAME="$name"
APP_DIR="$app"
COMPOSE_FILE="$compose"
DB_SERVICE="$service"
DB_NAME_ENV="$db_name_env"
DB_USER_ENV="$db_user_env"
DB_PASSWORD_ENV="$db_password_env"
EOF
    chmod 600 "$target_file"
    log_info "Cible PostgreSQL '$name' enregistrée."
}

if config_has "DB_BACKUP_ENABLED"; then
    if parse_boolean "$(config_get DB_BACKUP_ENABLED)"; then
        DB_BACKUP_ENABLED=true

        compgen -G "$BACKUP_TARGETS_DIR/*.conf" >/dev/null || {
            log_error "DB_BACKUP_ENABLED est actif mais aucune cible PostgreSQL n'est installée."
            log_info "Ajoutez des fichiers dans $BACKUP_TARGETS_DIR avant de relancer."
            exit 1
        }
    else
        log_info "Sauvegardes PostgreSQL désactivées par la configuration."
    fi
else
    if confirm "Configurer les sauvegardes PostgreSQL ?"; then
        DB_BACKUP_ENABLED=true

        if compgen -G "$BACKUP_TARGETS_DIR/*.conf" >/dev/null; then
            log_info "Cibles PostgreSQL existantes :"
            for target in "$BACKUP_TARGETS_DIR"/*.conf; do log "  $(basename "$target" .conf)"; done
        fi

        while confirm "Ajouter une base PostgreSQL ?"; do
            add_database_target || log_warn "Cible ignorée."
        done

        compgen -G "$BACKUP_TARGETS_DIR/*.conf" >/dev/null || DB_BACKUP_ENABLED=false
    else
        log_info "Sauvegardes PostgreSQL désactivées."
    fi
fi
