#!/usr/bin/env bash

## Installation et configuration de Docker Engine
## Ubuntu Server LTS
##
## Ce module :
## - installe Docker depuis le dépôt officiel
## - installe Docker Compose v2
## - active Docker au démarrage
## - configure la rotation des logs
## - active live-restore
## - ajoute l'utilisateur administrateur au groupe docker
## - vérifie l'installation

set -euo pipefail

# ---------------------------------------------------------------------------
# Variables / librairies
# ---------------------------------------------------------------------------

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

source "$PROJECT_DIR/lib/log.sh"
source "$PROJECT_DIR/lib/prompt.sh"

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
DOCKER_KEYRING="/etc/apt/keyrings/docker.asc"
DOCKER_SOURCE="/etc/apt/sources.list.d/docker.sources"

# ---------------------------------------------------------------------------
# Vérification des privilèges
# ---------------------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    log_error "Ce module doit être exécuté avec les privilèges root."
    log_info "Utilisez : sudo setup docker"
    exit 1
fi

# ---------------------------------------------------------------------------
# Détection de l'utilisateur administrateur
# ---------------------------------------------------------------------------

# Si le script est exécuté via sudo, SUDO_USER contient l'utilisateur réel.
# Sinon, on utilise l'utilisateur courant.
ADMIN_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"

# Protection contre un résultat vide ou root.
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

log_info "Utilisateur administrateur détecté : $ADMIN_USER"

# ---------------------------------------------------------------------------
# Vérification système
# ---------------------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    log_error "Impossible d'identifier le système."
    exit 1
fi

. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    log_error "Ce module est prévu uniquement pour Ubuntu Server."
    exit 1
fi

UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

if [ -z "$UBUNTU_CODENAME" ]; then
    log_error "Impossible de déterminer la version Ubuntu."
    exit 1
fi

ARCH="$(dpkg --print-architecture)"

log_info "Ubuntu détecté : ${VERSION_ID:-inconnue} ($UBUNTU_CODENAME)"
log_info "Architecture : $ARCH"

# ---------------------------------------------------------------------------
# Suppression des paquets Docker potentiellement conflictuels
# ---------------------------------------------------------------------------

log_info "Vérification des paquets Docker conflictuels..."

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
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
        | grep -q "install ok installed"; then
        PACKAGES_TO_REMOVE+=("$package")
    fi
done

if [ "${#PACKAGES_TO_REMOVE[@]}" -gt 0 ]; then
    log_warn "Paquets conflictuels détectés : ${PACKAGES_TO_REMOVE[*]}"
    apt-get remove -y "${PACKAGES_TO_REMOVE[@]}"
else
    log_info "Aucun paquet Docker conflictuel détecté."
fi

# ---------------------------------------------------------------------------
# Installation des dépendances
# ---------------------------------------------------------------------------

log_info "Installation des dépendances Docker..."

apt-get update
apt-get install -y \
    ca-certificates \
    curl

# ---------------------------------------------------------------------------
# Configuration du dépôt officiel Docker
# ---------------------------------------------------------------------------

log_info "Configuration du dépôt officiel Docker..."

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o "$DOCKER_KEYRING"

chmod a+r "$DOCKER_KEYRING"

cat > "$DOCKER_SOURCE" <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $UBUNTU_CODENAME
Components: stable
Architectures: $ARCH
Signed-By: $DOCKER_KEYRING
EOF

apt-get update

# ---------------------------------------------------------------------------
# Installation de Docker Engine
# ---------------------------------------------------------------------------

log_info "Installation de Docker Engine et Docker Compose..."

apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# ---------------------------------------------------------------------------
# Configuration du daemon Docker
# ---------------------------------------------------------------------------

log_info "Configuration du daemon Docker..."

mkdir -p /etc/docker

# Sauvegarde de la configuration existante avant modification.
if [ -f "$DOCKER_DAEMON_FILE" ]; then
    BACKUP_FILE="${DOCKER_DAEMON_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$DOCKER_DAEMON_FILE" "$BACKUP_FILE"
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

# Vérification syntaxique JSON.
if ! python3 -m json.tool "$DOCKER_DAEMON_FILE" >/dev/null 2>&1; then
    log_error "Le fichier $DOCKER_DAEMON_FILE contient un JSON invalide."

    if [ -n "${BACKUP_FILE:-}" ] && [ -f "$BACKUP_FILE" ]; then
        log_warn "Restauration de la configuration précédente..."
        cp "$BACKUP_FILE" "$DOCKER_DAEMON_FILE"
    fi

    exit 1
fi

# ---------------------------------------------------------------------------
# Activation du service Docker
# ---------------------------------------------------------------------------

log_info "Activation du service Docker..."

systemctl enable docker.service
systemctl enable containerd.service

# Docker recommande le reload pour prendre en compte live-restore lorsque
# le daemon fonctionne déjà. Lors d'une première installation, on démarre
# simplement le service.
if systemctl is-active --quiet docker; then
    log_info "Rechargement de la configuration Docker..."

    if ! systemctl reload docker; then
        log_warn "Le reload Docker a échoué, tentative de redémarrage..."

        if ! systemctl restart docker; then
            log_error "Impossible de redémarrer Docker."

            if [ -n "${BACKUP_FILE:-}" ] && [ -f "$BACKUP_FILE" ]; then
                log_warn "Rollback de daemon.json..."
                cp "$BACKUP_FILE" "$DOCKER_DAEMON_FILE"
                systemctl restart docker || true
            fi

            exit 1
        fi
    fi
else
    systemctl start docker
fi

# ---------------------------------------------------------------------------
# Gestion des permissions utilisateur
# ---------------------------------------------------------------------------

log_info "Configuration des droits Docker pour '$ADMIN_USER'..."

if ! getent group docker >/dev/null 2>&1; then
    log_info "Création du groupe docker..."
    groupadd docker
fi

if id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -qx docker; then
    log_info "L'utilisateur '$ADMIN_USER' appartient déjà au groupe docker."
    USER_GROUP_UPDATED=false
else
    usermod -aG docker "$ADMIN_USER"
    USER_GROUP_UPDATED=true
    log_info "Utilisateur '$ADMIN_USER' ajouté au groupe docker."
fi

# ---------------------------------------------------------------------------
# Vérifications
# ---------------------------------------------------------------------------

log_info "Vérification de Docker..."

DOCKER_OK=false
COMPOSE_OK=false
DAEMON_OK=false
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

if id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -qx docker; then
    GROUP_OK=true
fi

# ---------------------------------------------------------------------------
# Résumé
# ---------------------------------------------------------------------------

echo ""
log_info "--------------------------------------------------"
log_info "Résumé de l'installation Docker"
log_info "--------------------------------------------------"

if $DOCKER_OK; then
    log_info "Docker ............. OK"
else
    log_error "Docker ............. ERREUR"
fi

if $COMPOSE_OK; then
    log_info "Docker Compose ..... OK"
else
    log_error "Docker Compose ..... ERREUR"
fi

if $DAEMON_OK; then
    log_info "Daemon Docker ...... OK"
else
    log_error "Daemon Docker ...... ERREUR"
fi

if $GROUP_OK; then
    log_info "Utilisateur ........ OK ($ADMIN_USER)"
else
    log_error "Utilisateur ........ ERREUR ($ADMIN_USER)"
fi

echo ""

docker --version
docker compose version

echo ""

# ---------------------------------------------------------------------------
# Validation finale
# ---------------------------------------------------------------------------

if ! $DOCKER_OK || ! $COMPOSE_OK || ! $DAEMON_OK || ! $GROUP_OK; then
    log_error "L'installation Docker n'est pas complètement fonctionnelle."
    exit 1
fi

if [ "$USER_GROUP_UPDATED" = true ]; then
    log_warn "IMPORTANT : les nouveaux droits Docker ne sont pas encore actifs"
    log_warn "dans la session SSH actuelle."
    log_warn ""
    log_warn "Déconnectez-vous puis reconnectez-vous au serveur avant"
    log_warn "d'utiliser Docker sans sudo."
fi

log_info "Installation et configuration Docker terminées avec succès."
