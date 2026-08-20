#!/usr/bin/env bash
log_step "Restauration d'une release Docker"

restore_release() {
    local backups id dir staging apps app compose_file source_env temp_env

    backups="$(list_backups files)"
    [ -n "$backups" ] || { log_error "Aucun snapshot fichier disponible."; return 1; }

    log_info "Snapshots disponibles pour la restauration de release :"
    while IFS= read -r x; do log "  $x"; done <<< "$backups"

    id="$(ask_input "Snapshot de release" "$(head -n1 <<< "$backups")" "RESTORE_RELEASE_BACKUP")"
    grep -qxF "$id" <<< "$backups" || { log_error "Snapshot inconnu : $id"; return 1; }

    dir="$(download_complete_backup files "$id")" || return 1
    staging="$dir/release-staging"
    mkdir -p "$staging"

    if ! zstd -dc "$dir/system.tar.zst" | tar -xf - -C "$staging"; then
        log_error "Impossible d'extraire le snapshot de release."
        return 1
    fi

    apps="$(find "$staging/srv/apps" -mindepth 1 -maxdepth 1 -type d \
        -printf '%f\n' 2>/dev/null | sort)"
    [ -n "$apps" ] || { log_error "Aucune application disponible."; return 1; }

    log_info "Applications disponibles :"
    while IFS= read -r x; do log "  $x"; done <<< "$apps"

    app="$(ask_input "Application" "$(head -n1 <<< "$apps")" "RESTORE_APP")"
    grep -qxF "$app" <<< "$apps" || { log_error "Application inconnue : $app"; return 1; }

    compose_file="$(ask_input "Fichier Compose" "compose.yaml" "RESTORE_COMPOSE_FILE")"
    [ -f "/srv/apps/$app/$compose_file" ] || { log_error "Compose introuvable."; return 1; }

    source_env="$staging/srv/apps/$app/.env.prod.local"
    [ -f "$source_env" ] || {
        log_error "État de release introuvable dans le snapshot : $source_env"
        return 1
    }

    temp_env="$(mktemp)"
    cp "$source_env" "$temp_env"
    chmod 600 "$temp_env"

    if ! confirm_required "Confirmer le rechargement Docker ?" "RESTORE_RELEASE_CONFIRM"; then
        rm -f "$temp_env"
        log_info "Restauration annulée."
        return 0
    fi

    (
      cd "/srv/apps/$app"
      docker compose --env-file "$temp_env" -f "$compose_file" pull
      docker compose --env-file "$temp_env" -f "$compose_file" up -d --remove-orphans
    ) || { rm -f "$temp_env"; log_error "Échec du rechargement."; return 1; }

    rm -f "$temp_env"
    log_info "Release du snapshot '$id' chargée pour '$app'."
}
