#!/usr/bin/env bash

## ============================================================================
## Module 20_docker
## Installation et configuration de Docker Engine
## Ubuntu Server LTS
##
## Ce module :
## - vérifie les privilèges administrateur
## - détecte l'utilisateur administrateur
## - vérifie la compatibilité Ubuntu
## - supprime les paquets Docker conflictuels
## - configure le dépôt officiel Docker
## - installe Docker Engine
## - installe Docker Compose v2
## - configure le daemon Docker
## - configure la rotation des logs
## - active live-restore
## - configure les droits utilisateur
## - vérifie l'état final de Docker
## ============================================================================

set -euo pipefail


# ----------------------------------------------------------------------------
# Variables et librairies
# ----------------------------------------------------------------------------

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

source "$PROJECT_DIR/lib/log.sh"
source "$PROJECT_DIR/lib/prompt.sh"

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
DOCKER_KEYRING="/etc/apt/keyrings/docker.asc"
DOCKER_SOURCE="/etc/apt/sources.list.d/docker.sources"

BACKUP_FILE=""
USER_GROUP_UPDATED=false


# ----------------------------------------------------------------------------
# Fonctions utilitaires
# ----------------------------------------------------------------------------

##
# Vérifie si un paquet Debian est installé.
##
package_is_installed() {
    local package="$1"

    dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
        | grep -q "install ok installed"
}


# ----------------------------------------------------------------------------
# Initialisation du module
# ----------------------------------------------------------------------------

log "Installation et configuration de Docker"


# ----------------------------------------------------------------------------
# Vérification des privilèges
# ----------------------------------------------------------------------------

log_step "Vérification des privilèges administrateur"

if [ "$EUID" -ne 0 ]; then
    log_error "Ce module nécessite les privilèges administrateur."
    log_info "Relancez la commande avec : sudo setup docker"
    exit 1
fi


# ----------------------------------------------------------------------------
# Détection de l'utilisateur administrateur
# ----------------------------------------------------------------------------

log_step "Détection de l'utilisateur administrateur"

ADMIN_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"

if [ -z "$ADMIN_USER" ] || [ "$ADMIN_USER" = "root" ]; then
    log_warn "Impossible de détecter automatiquement l'utilisateur administrateur."

    ADMIN_USER=$(ask_input "Utilisateur à autoriser à utiliser Docker" "")

    if [ -z "$ADMIN_USER" ]; then
        log_error "Aucun utilisateur renseigné."
        exit 1
    fi
fi

if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    log_error "L'utilisateur '$ADMIN_USER' n'existe pas."
    exit 1
fi

log "Utilisateur administrateur : $ADMIN_USER"


# ----------------------------------------------------------------------------
# Vérification du système
# ----------------------------------------------------------------------------

log_step "Vérification du système"

if [ ! -f /etc/os-release ]; then
    log_error "Impossible d'identifier le système d'exploitation."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    log_error "Ce module est prévu uniquement pour Ubuntu Server."
    log_info "Système détecté : ${ID:-inconnu}"
    exit 1
fi

UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

if [ -z "$UBUNTU_CODENAME" ]; then
    log_error "Impossible de déterminer le nom de version Ubuntu."
    exit 1
fi

ARCH="$(dpkg --print-architecture)"

log "Ubuntu ${VERSION_ID:-inconnue} ($UBUNTU_CODENAME) : $ARCH"


# ----------------------------------------------------------------------------
# Détection et suppression des paquets conflictuels
# ----------------------------------------------------------------------------

log_step "Recherche de paquets Docker conflictuels"

CONFLICTING_PACKAGES=(
    docker.io
    docker-compose
    docker-compose-v2
    docker-doc
    docker-buildx
    podman-docker
    containerd
    runc
)

PACKAGES_TO_REMOVE=()

for package in "${CONFLICTING_PACKAGES[@]}"; do
    if package_is_installed "$package"; then
        PACKAGES_TO_REMOVE+=("$package")
    fi
done

if [ "${#PACKAGES_TO_REMOVE[@]}" -gt 0 ]; then
    log_warn "Paquets conflictuels détectés : ${PACKAGES_TO_REMOVE[*]}"
    log_info "Suppression des paquets conflictuels..."

    run_quiet \
        "Impossible de supprimer les paquets Docker conflictuels." \
        apt-get remove -y "${PACKAGES_TO_REMOVE[@]}" \
        || exit 1
else
    log "Aucun paquet conflictuel détecté."
fi


# ----------------------------------------------------------------------------
# Installation des dépendances
# ----------------------------------------------------------------------------

log_step "Installation des dépendances"

run_quiet \
    "Impossible de mettre à jour les dépôts APT." \
    apt-get update \
    || exit 1

run_quiet \
    "Impossible d'installer les dépendances Docker." \
    apt-get install -y ca-certificates curl \
    || exit 1

# ----------------------------------------------------------------------------
# Configuration du dépôt officiel Docker
# ----------------------------------------------------------------------------

log_step "Configuration du dépôt officiel Docker"

if ! install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1; then
    log_error "Impossible de créer le dossier /etc/apt/keyrings."
    exit 1
fi

if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o "$DOCKER_KEYRING" >/dev/null 2>&1; then
    log_error "Impossible de télécharger la clé GPG officielle Docker."
    log_info "Vérifiez la connexion Internet et l'accès à download.docker.com."
    exit 1
fi

chmod a+r "$DOCKER_KEYRING"

cat > "$DOCKER_SOURCE" <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $UBUNTU_CODENAME
Components: stable
Architectures: $ARCH
Signed-By: $DOCKER_KEYRING
EOF

run_quiet \
    "Impossible de mettre à jour APT après ajout du dépôt Docker." \
    apt-get update \
    || exit 1

log "Dépôt Docker configuré."


# ----------------------------------------------------------------------------
# Installation de Docker Engine
# ----------------------------------------------------------------------------

log_step "Installation de Docker Engine et Docker Compose"

run_quiet \
    "Impossible d'installer Docker Engine." \
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
    || exit 1


# ----------------------------------------------------------------------------
# Configuration du daemon Docker
# ----------------------------------------------------------------------------

log_step "Configuration du daemon Docker"

if ! mkdir -p /etc/docker; then
    log_error "Impossible de créer le dossier /etc/docker."
    exit 1
fi

if [ -f "$DOCKER_DAEMON_FILE" ]; then
    BACKUP_FILE="${DOCKER_DAEMON_FILE}.bak.$(date +%Y%m%d-%H%M%S)"

    if ! cp "$DOCKER_DAEMON_FILE" "$BACKUP_FILE"; then
        log_error "Impossible de sauvegarder la configuration Docker existante."
        exit 1
    fi

    log_info "Sauvegarde créée : $BACKUP_FILE"
fi

cat > "$DOCKER_DAEMON_FILE" <<'EOF'
{
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "5"
  }
}
EOF

chmod 644 "$DOCKER_DAEMON_FILE"


# ----------------------------------------------------------------------------
# Validation du fichier daemon.json
# ----------------------------------------------------------------------------

log_step "Validation de la configuration Docker"

if ! python3 -m json.tool "$DOCKER_DAEMON_FILE" >/dev/null 2>&1; then
    log_error "Le fichier $DOCKER_DAEMON_FILE contient un JSON invalide."

    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        log_warn "Restauration de la configuration précédente."

        if cp "$BACKUP_FILE" "$DOCKER_DAEMON_FILE"; then
            log_info "Configuration précédente restaurée."
        else
            log_error "Impossible de restaurer le fichier daemon.json."
        fi
    fi

    exit 1
fi

log "Configuration daemon.json valide."


# ----------------------------------------------------------------------------
# Activation des services Docker
# ----------------------------------------------------------------------------

log_step "Activation des services Docker"

run_quiet \
    "Impossible d'activer docker.service au démarrage." \
    systemctl enable docker.service \
    || exit 1

run_quiet \
    "Impossible d'activer containerd.service au démarrage." \
    systemctl enable containerd.service \
    || exit 1


# ----------------------------------------------------------------------------
# Chargement de la configuration Docker
# ----------------------------------------------------------------------------

log_step "Chargement de la configuration Docker"

if systemctl is-active --quiet docker; then
    log_info "Docker est déjà actif, tentative de rechargement."

    if ! run_quiet \
        "Le rechargement du daemon Docker a échoué." \
        systemctl reload docker; then

        log_warn "Tentative de redémarrage complet du daemon Docker."

        if ! run_quiet \
            "Impossible de redémarrer Docker." \
            systemctl restart docker; then

            if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
                log_warn "Rollback de la configuration Docker."

                cp "$BACKUP_FILE" "$DOCKER_DAEMON_FILE"

                if run_quiet \
                    "Impossible de redémarrer Docker après rollback." \
                    systemctl restart docker; then
                    log_info "Configuration précédente restaurée."
                fi
            fi

            exit 1
        fi
    fi
else
    log_info "Démarrage du daemon Docker."

    run_quiet \
        "Impossible de démarrer Docker." \
        systemctl start docker \
        || exit 1
fi


# ----------------------------------------------------------------------------
# Gestion des permissions utilisateur
# ----------------------------------------------------------------------------

log_step "Configuration des droits utilisateur Docker"

if ! getent group docker >/dev/null 2>&1; then
    log_info "Création du groupe docker."

    run_quiet \
        "Impossible de créer le groupe docker." \
        groupadd docker \
        || exit 1
fi

if id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -qx docker; then
    log_info "L'utilisateur '$ADMIN_USER' appartient déjà au groupe docker."
else
    if run_quiet \
        "Impossible d'ajouter '$ADMIN_USER' au groupe docker." \
        usermod -aG docker "$ADMIN_USER"; then

        USER_GROUP_UPDATED=true
        log_info "Utilisateur '$ADMIN_USER' ajouté au groupe docker."
    else
        exit 1
    fi
fi


# ----------------------------------------------------------------------------
# Vérifications finales
# ----------------------------------------------------------------------------

log_step "Vérification de l'installation Docker"

DOCKER_OK=false
COMPOSE_OK=false
DAEMON_OK=false
CONTAINERD_OK=false
GROUP_OK=false

if docker version >/dev/null 2>&1; then
    DOCKER_OK=true
fi

if docker compose version >/dev/null 2>&1; then
    COMPOSE_OK=true
fi

if systemctl is-active --quiet docker; then
    DAEMON_OK=true
fi

if systemctl is-active --quiet containerd; then
    CONTAINERD_OK=true
fi

if id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -qx docker; then
    GROUP_OK=true
fi


# ----------------------------------------------------------------------------
# Résumé
# ----------------------------------------------------------------------------

log ""
log_step "Résumé de l'installation"

if $DOCKER_OK; then
    log "Docker Engine ............ OK"
else
    log_error "Docker Engine ............ ERREUR"
fi

if $COMPOSE_OK; then
    log "Docker Compose ........... OK"
else
    log_error "Docker Compose ........... ERREUR"
fi

if $DAEMON_OK; then
    log "Service Docker ........... OK"
else
    log_error "Service Docker ........... ERREUR"
fi

if $CONTAINERD_OK; then
    log "Service containerd ....... OK"
else
    log_error "Service containerd ...... ERREUR"
fi

if $GROUP_OK; then
    log "Droits utilisateur ....... OK ($ADMIN_USER)"
else
    log_error "Droits utilisateur ...... ERREUR ($ADMIN_USER)"
fi

log ""

if $DOCKER_OK; then
    DOCKER_VERSION="$(docker --version 2>/dev/null || true)"
    log_info "$DOCKER_VERSION"
fi

if $COMPOSE_OK; then
    COMPOSE_VERSION="$(docker compose version 2>/dev/null || true)"
    log_info "$COMPOSE_VERSION"
fi


# ----------------------------------------------------------------------------
# Validation finale
# ----------------------------------------------------------------------------

if ! $DOCKER_OK \
    || ! $COMPOSE_OK \
    || ! $DAEMON_OK \
    || ! $CONTAINERD_OK \
    || ! $GROUP_OK; then

    log_error "L'installation Docker n'est pas complètement fonctionnelle."
    log_info "Consultez les erreurs ci-dessus avant de poursuivre."
    exit 1
fi


# ----------------------------------------------------------------------------
# Information session utilisateur
# ----------------------------------------------------------------------------

if [ "$USER_GROUP_UPDATED" = true ]; then
    log_warn "Les nouveaux droits Docker ne sont pas actifs dans la session actuelle."
    log_info "Déconnectez-vous puis reconnectez-vous avant d'utiliser Docker sans sudo."
fi


# ----------------------------------------------------------------------------
# Fin du module
# ----------------------------------------------------------------------------

log_success "Docker Engine et Docker Compose sont installés et opérationnels."
