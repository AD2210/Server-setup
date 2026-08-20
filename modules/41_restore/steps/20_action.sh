#!/usr/bin/env bash
log_step "Choix de la restauration"

log ""
log "  1) Restaurer une base PostgreSQL"
log "  2) Extraire un snapshot logique en staging"
log "  3) Restaurer une release Docker"
log "  4) Procédure de disaster recovery"
log ""

ACTION="$(ask_input "Choix" "1" "RESTORE_ACTION")"

list_backups() {
    local category="$1" prefix local_root dir id

    case "$category" in
        databases) prefix="db" ;;
        files) prefix="files" ;;
        *) log_error "Catégorie de backup inconnue : $category"; return 1 ;;
    esac

    local_root="${LOCAL_BACKUP_ROOT:-/var/backups/server-setup}"

    # Why: après une installation normale, une copie locale évite un transfert
    # inutile. En disaster recovery, les entrées distantes restent disponibles.
    if [ -d "$local_root" ]; then
        while IFS= read -r dir; do
            id="${dir##*/$prefix-}"
            printf 'local:%s\n' "$id"
        done < <(find "$local_root" -mindepth 1 -maxdepth 1 -type d \
            -name "$prefix-*" -printf '%f\n' | sed "s/^$prefix-//" | sort -r \
            | sed "s#^#$local_root/$prefix-#")
    fi

    rclone lsf "${RCLONE_REMOTE}:${REMOTE_ROOT}/${category}" \
        --config "$RCLONE_CONFIG" --dirs-only 2>/dev/null \
        | sed 's:/$::' | sort -r | sed 's/^/remote:/' || true
}

download_complete_backup() {
    local category="$1" selection="$2" source id prefix
    local remote local_source local_dir

    source="${selection%%:*}"
    id="${selection#*:}"

    case "$category" in
        databases) prefix="db" ;;
        files) prefix="files" ;;
        *) log_error "Catégorie de backup inconnue : $category"; return 1 ;;
    esac

    [[ "$id" =~ ^[0-9TZ._-]+$ ]] || {
        log_error "Identifiant de backup invalide : $id"
        return 1
    }

    local_dir="$RESTORE_ROOT/${category}-${source}-${id}"

    if [ "$source" = "local" ]; then
        local_source="${LOCAL_BACKUP_ROOT:-/var/backups/server-setup}/$prefix-$id"
        [ -d "$local_source" ] || { log_error "Backup local introuvable : $local_source"; return 1; }
    elif [ "$source" = "remote" ]; then
        remote="${RCLONE_REMOTE}:${REMOTE_ROOT}/${category}/${id}"
    else
        log_error "Source de backup inconnue : $source"
        return 1
    fi

    if [ "$source" = "local" ]; then
        [ -f "$local_source/COMPLETE" ]
    else
        rclone lsf "$remote" --config "$RCLONE_CONFIG" --files-only \
            | grep -qx COMPLETE
    fi || {
        log_error "Sauvegarde incomplète : $id"
        return 1
    }

    rm -rf "$local_dir"
    mkdir -p "$local_dir"

    if [ "$source" = "local" ]; then
        run_quiet "Copie du backup local impossible." \
            cp -a "$local_source/." "$local_dir/" || return 1
    else
        run_quiet "Téléchargement impossible." \
            rclone copy "$remote" "$local_dir" --config "$RCLONE_CONFIG" || return 1
    fi

    (
        cd "$local_dir"
        sha256sum -c SHA256SUMS >/dev/null
    ) || {
        log_error "Checksum invalide."
        return 1
    }

    printf '%s\n' "$local_dir"
}

restore_db() {
    local backups id dir targets target target_file dump compose_file services_output service
    local -a running_services=() application_services=()

    backups="$(list_backups databases)"
    [ -n "$backups" ] || { log_error "Aucun backup DB."; return 1; }

    log_info "Backups DB :"
    while IFS= read -r x; do log "  $x"; done <<< "$backups"

    id="$(ask_input "Backup DB" "$(head -n1 <<< "$backups")" "RESTORE_DB_BACKUP")"
    grep -qxF "$id" <<< "$backups" || { log_error "Backup inconnu."; return 1; }

    dir="$(download_complete_backup databases "$id")" || return 1

    compgen -G "$TARGETS_DIR/*.conf" >/dev/null || {
        log_error "Aucune cible DB configurée."
        return 1
    }

    targets="$(for f in "$TARGETS_DIR"/*.conf; do basename "$f" .conf; done)"
    log_info "Cibles :"
    while IFS= read -r x; do log "  $x"; done <<< "$targets"

    target="$(ask_input "Cible DB" "$(head -n1 <<< "$targets")" "RESTORE_DB_TARGET")"
    target_file="$TARGETS_DIR/$target.conf"
    dump="$dir/$target.dump"

    [ -f "$target_file" ] && [ -f "$dump" ] || {
        log_error "Cible ou dump introuvable."
        return 1
    }

    source "$target_file"

    compose_file="$(basename "$COMPOSE_FILE")"

    log_warn "La restauration va interrompre les services applicatifs et remplacer entièrement la base '$target'."
    confirm_required "Confirmer la restauration de '$target' ?" "RESTORE_DB_CONFIRM" || return 0

    # Why: les connexions applicatives doivent être coupées avant la suppression
    # de la base afin d'éviter des transactions concurrentes pendant le restore.
    if ! services_output="$(
        cd "$APP_DIR" && docker compose -f "$compose_file" ps --status running --services
    )"; then
        log_error "Impossible de déterminer les services actuellement actifs."
        return 1
    fi

    mapfile -t running_services <<< "$services_output"
    for service in "${running_services[@]}"; do
        [ -n "$service" ] && [ "$service" != "$DB_SERVICE" ] && application_services+=("$service")
    done

    if [ "${#application_services[@]}" -gt 0 ] && ! (
        cd "$APP_DIR"
        docker compose -f "$compose_file" stop \
            "${application_services[@]}" >/dev/null
    ); then
        log_error "Impossible d'arrêter les services avant la restauration."
        return 1
    fi

    # Le service PostgreSQL doit rester disponible pour exécuter DROP/CREATE.
    if ! (
        cd "$APP_DIR"
        docker compose -f "$compose_file" up -d "$DB_SERVICE" >/dev/null
    ); then
        log_error "Impossible de démarrer le service PostgreSQL."
        docker compose -f "$compose_file" up -d --remove-orphans >/dev/null 2>&1 || true
        return 1
    fi

    if ! (
        cd "$APP_DIR"
        docker compose -f "$compose_file" exec -T \
            -e BACKUP_DB_NAME_ENV="$DB_NAME_ENV" \
            -e BACKUP_DB_USER_ENV="$DB_USER_ENV" \
            -e BACKUP_DB_PASSWORD_ENV="$DB_PASSWORD_ENV" \
            "$DB_SERVICE" sh -lc '
                DB_NAME="$(printenv "$BACKUP_DB_NAME_ENV")"
                DB_USER="$(printenv "$BACKUP_DB_USER_ENV")"
                DB_PASSWORD="$(printenv "$BACKUP_DB_PASSWORD_ENV")"
                [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] || exit 20
                export PGPASSWORD="$DB_PASSWORD"

                psql -v ON_ERROR_STOP=1 -v db_name="$DB_NAME" -U "$DB_USER" -d postgres \
                    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = :'db_name' AND pid <> pg_backend_pid(); DROP DATABASE IF EXISTS :\"db_name\"; CREATE DATABASE :\"db_name\";"

                pg_restore --no-owner --no-privileges \
                    -U "$DB_USER" -d "$DB_NAME"
            ' < "$dump"
    ); then
        log_error "Échec de la suppression, recréation ou restauration de la base."
        docker compose -f "$compose_file" up -d --remove-orphans >/dev/null 2>&1 || true
        return 1
    fi

    log_info "Base '$target' restaurée depuis '$id'."

    # Le compose redémarre les services et rétablit les connexions applicatives.
    if ! (
        cd "$APP_DIR"
        docker compose -f "$compose_file" up -d --remove-orphans >/dev/null
    ); then
        log_error "La base est restaurée, mais le redémarrage des services a échoué."
        return 1
    fi

    if ! (
        cd "$APP_DIR"
        docker compose -f "$compose_file" exec -T \
            -e BACKUP_DB_NAME_ENV="$DB_NAME_ENV" \
            -e BACKUP_DB_USER_ENV="$DB_USER_ENV" \
            "$DB_SERVICE" sh -lc '
                DB_NAME="$(printenv "$BACKUP_DB_NAME_ENV")"
                DB_USER="$(printenv "$BACKUP_DB_USER_ENV")"
                exec pg_isready -U "$DB_USER" -d "$DB_NAME"
            ' >/dev/null
    ); then
        log_error "Le healthcheck PostgreSQL a échoué après la restauration."
        return 1
    fi

    if ! (
        cd "$APP_DIR"
        docker compose -f "$compose_file" ps
    ); then
        log_error "Le healthcheck Compose a échoué après la restauration."
        return 1
    fi

    log_success "Restauration PostgreSQL terminée et services applicatifs relancés."
}

restore_files() {
    local backups id dir staging

    backups="$(list_backups files)"
    [ -n "$backups" ] || { log_error "Aucun snapshot logique."; return 1; }

    log_info "Snapshots fichiers :"
    while IFS= read -r x; do log "  $x"; done <<< "$backups"

    id="$(ask_input "Snapshot fichiers" "$(head -n1 <<< "$backups")" "RESTORE_FILES_BACKUP")"
    grep -qxF "$id" <<< "$backups" || { log_error "Snapshot inconnu."; return 1; }

    dir="$(download_complete_backup files "$id")" || return 1
    staging="$dir/staging"
    mkdir -p "$staging"

    zstd -dc "$dir/system.tar.zst" | tar -xf - -C "$staging"
    log_info "Snapshot extrait : $staging"
    log_warn "Aucun fichier système n'a été écrasé automatiquement."
}

show_dr() {
    log ""
    log "  Procédure de reprise après corruption complète :"
    log "  1. Restaurer/créer le VPS depuis le dernier snapshot fournisseur."
    log "  2. Vérifier réseau, SSH, Docker et Caddy."
    log "  3. Vérifier /opt/Server-setup et la configuration rclone."
    log "  4. Exécuter : sudo setup restore"
    log "  5. Restaurer les dumps PostgreSQL plus récents que le snapshot VPS."
    log "  6. Contrôler les applications avant remise en production."
    log ""
}

case "$ACTION" in
    1) restore_db ;;
    2) restore_files ;;
    3) ;;
    4) show_dr ;;
    *) log_error "Choix invalide : $ACTION"; exit 1 ;;
esac
