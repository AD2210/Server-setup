#!/usr/bin/env bash
log_step "Choix de la restauration"

log ""
log "  1) Restaurer une base PostgreSQL"
log "  2) Extraire un snapshot logique en staging"
log "  3) Restaurer une release Docker"
log "  4) Procédure de disaster recovery"
log ""

ACTION="$(ask_input "Choix" "1")"

list_backups() {
    local category="$1"
    rclone lsf "${RCLONE_REMOTE}:${REMOTE_ROOT}/${category}" \
        --config "$RCLONE_CONFIG" --dirs-only 2>/dev/null \
        | sed 's:/$::' | sort -r
}

download_complete_backup() {
    local category="$1" id="$2"
    local remote="${RCLONE_REMOTE}:${REMOTE_ROOT}/${category}/${id}"
    local local_dir="$RESTORE_ROOT/${category}-${id}"

    rclone lsf "$remote" --config "$RCLONE_CONFIG" --files-only \
        | grep -qx COMPLETE || {
        log_error "Sauvegarde incomplète : $id"
        return 1
    }

    rm -rf "$local_dir"
    mkdir -p "$local_dir"
    run_quiet "Téléchargement impossible." \
        rclone copy "$remote" "$local_dir" --config "$RCLONE_CONFIG" || return 1

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
    local backups id dir targets target target_file dump

    backups="$(list_backups databases)"
    [ -n "$backups" ] || { log_error "Aucun backup DB."; return 1; }

    log_info "Backups DB :"
    while IFS= read -r x; do log "  $x"; done <<< "$backups"

    id="$(ask_input "Backup DB" "$(head -n1 <<< "$backups")")"
    grep -qxF "$id" <<< "$backups" || { log_error "Backup inconnu."; return 1; }

    dir="$(download_complete_backup databases "$id")" || return 1

    compgen -G "$TARGETS_DIR/*.conf" >/dev/null || {
        log_error "Aucune cible DB configurée."
        return 1
    }

    targets="$(for f in "$TARGETS_DIR"/*.conf; do basename "$f" .conf; done)"
    log_info "Cibles :"
    while IFS= read -r x; do log "  $x"; done <<< "$targets"

    target="$(ask_input "Cible DB" "$(head -n1 <<< "$targets")")"
    target_file="$TARGETS_DIR/$target.conf"
    dump="$dir/$target.dump"

    [ -f "$target_file" ] && [ -f "$dump" ] || {
        log_error "Cible ou dump introuvable."
        return 1
    }

    source "$target_file"

    log_warn "La base cible sera nettoyée puis restaurée."
    confirm "Confirmer la restauration de '$target' ?" || return 0

    (
        cd "$APP_DIR"
        docker compose -f "$COMPOSE_FILE" exec -T \
            -e BACKUP_DB_NAME_ENV="$DB_NAME_ENV" \
            -e BACKUP_DB_USER_ENV="$DB_USER_ENV" \
            -e BACKUP_DB_PASSWORD_ENV="$DB_PASSWORD_ENV" \
            "$DB_SERVICE" sh -lc '
                DB_NAME="$(printenv "$BACKUP_DB_NAME_ENV")"
                DB_USER="$(printenv "$BACKUP_DB_USER_ENV")"
                DB_PASSWORD="$(printenv "$BACKUP_DB_PASSWORD_ENV")"
                export PGPASSWORD="$DB_PASSWORD"
                exec pg_restore --clean --if-exists --no-owner --no-privileges \
                    -U "$DB_USER" -d "$DB_NAME"
            ' < "$dump"
    )
}

restore_files() {
    local backups id dir staging

    backups="$(list_backups files)"
    [ -n "$backups" ] || { log_error "Aucun snapshot logique."; return 1; }

    log_info "Snapshots fichiers :"
    while IFS= read -r x; do log "  $x"; done <<< "$backups"

    id="$(ask_input "Snapshot fichiers" "$(head -n1 <<< "$backups")")"
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
