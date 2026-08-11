#!/usr/bin/env bash
log_step "Restauration d'une release Docker"

restore_release() {
    command_exists server-release || { log_error "server-release absent."; return 1; }

    local apps app slot compose_file temp_env
    apps="$(find /srv/apps -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)"
    [ -n "$apps" ] || { log_error "Aucune application disponible."; return 1; }

    log_info "Applications disponibles :"
    while IFS= read -r x; do log "  $x"; done <<< "$apps"

    app="$(ask_input "Application" "$(head -n1 <<< "$apps")" "RESTORE_APP")"
    grep -qxF "$app" <<< "$apps" || { log_error "Application inconnue : $app"; return 1; }

    server-release show "$app"

    slot="$(ask_input "Release à charger (current/previous)" "previous" "RESTORE_RELEASE_SLOT")"
    case "$slot" in current|previous) ;; *) log_error "Slot invalide."; return 1 ;; esac

    compose_file="$(ask_input "Fichier Compose" "compose.yaml" "RESTORE_COMPOSE_FILE")"
    [ -f "/srv/apps/$app/$compose_file" ] || { log_error "Compose introuvable."; return 1; }

    temp_env="$(mktemp)"
    server-release env "$app" "$slot" > "$temp_env"
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
    log_info "Release '$slot' chargée pour '$app'."
}
