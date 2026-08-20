#!/usr/bin/env bash

## ============================================================================
## Étape 10 - Compte administrateur
##
## - détecte l'utilisateur initial
## - crée un compte administrateur dédié
## - réutilise les clés SSH existantes
## - configure sudo sans mot de passe
## ============================================================================

log_step "Configuration du compte administrateur"

SUDOERS_DIR="/etc/sudoers.d"
INITIAL_USER="${SUDO_USER:-root}"

create_admin_user() {
    local user="$1"

    if id "$user" >/dev/null 2>&1; then
        log_info "L'utilisateur '$user' existe déjà."
    else
        if ! useradd --create-home --shell /bin/bash --groups sudo "$user"; then
            log_error "Impossible de créer l'utilisateur '$user'."
            return 1
        fi
        log_info "Utilisateur '$user' créé."
    fi

    if ! id -nG "$user" | tr ' ' '\n' | grep -qx sudo; then
        usermod -aG sudo "$user" || {
            log_error "Impossible d'ajouter '$user' au groupe sudo."
            return 1
        }
    fi
}

copy_initial_ssh_key() {
    local source_user="$1"
    local target_user="$2"
    local source_home target_home source_keys target_ssh target_keys

    source_home="$(getent passwd "$source_user" | cut -d: -f6)"
    target_home="$(getent passwd "$target_user" | cut -d: -f6)"
    source_keys="$source_home/.ssh/authorized_keys"
    target_ssh="$target_home/.ssh"
    target_keys="$target_ssh/authorized_keys"

    if [ ! -s "$source_keys" ]; then
        log_error "Aucune clé SSH trouvée pour '$source_user'."
        log_info "Fichier attendu : $source_keys"
        return 1
    fi

    install -d -m 700 -o "$target_user" -g "$target_user" "$target_ssh"
    cp "$source_keys" "$target_keys"
    chown "$target_user:$target_user" "$target_keys"
    chmod 600 "$target_keys"

    log_info "Clé SSH de '$source_user' réutilisée pour '$target_user'."
}

configure_passwordless_sudo() {
    local user="$1"
    local sudo_file="$SUDOERS_DIR/server-admin"

    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user" >"$sudo_file"
    chmod 440 "$sudo_file"

    if ! visudo -cf "$sudo_file" >/dev/null 2>&1; then
        log_error "Configuration sudo invalide."
        rm -f "$sudo_file"
        return 1
    fi

    log_info "Sudo sans mot de passe configuré pour '$user'."
}

if ! id "$INITIAL_USER" >/dev/null 2>&1; then
    log_error "Utilisateur initial introuvable : $INITIAL_USER"
    exit 1
fi

log_info "Utilisateur initial détecté : $INITIAL_USER"

ADMIN_USER=$(ask_input "Nom de l'utilisateur administrateur" "admin" "ADMIN_USER")

if [ -z "$ADMIN_USER" ] || ! [[ "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    log_error "Nom d'utilisateur invalide : $ADMIN_USER"
    exit 1
fi

if [ "$ADMIN_USER" = "root" ]; then
    log_error "Le compte administrateur SSH ne doit pas être root."
    exit 1
fi

create_admin_user "$ADMIN_USER" || exit 1

# Si le module est rejoué après suppression du compte fournisseur et que
# l'admin existe déjà, ses clés sont conservées.
if [ "$INITIAL_USER" != "$ADMIN_USER" ]; then
    copy_initial_ssh_key "$INITIAL_USER" "$ADMIN_USER" || exit 1
fi

configure_passwordless_sudo "$ADMIN_USER" || exit 1
