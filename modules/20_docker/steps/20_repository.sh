#!/usr/bin/env bash
log_step "Préparation du dépôt officiel Docker"

DOCKER_KEYRING="/etc/apt/keyrings/docker.asc"
DOCKER_SOURCE="/etc/apt/sources.list.d/docker.sources"
ARCH="$(dpkg --print-architecture)"
UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

[ -n "$UBUNTU_CODENAME" ] || {
    log_error "Impossible de déterminer le nom de version Ubuntu."
    exit 1
}

package_is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

CONFLICTING_PACKAGES=(
    docker.io docker-compose docker-compose-v2 docker-doc
    docker-buildx podman-docker containerd runc
)

PACKAGES_TO_REMOVE=()
for package in "${CONFLICTING_PACKAGES[@]}"; do
    package_is_installed "$package" && PACKAGES_TO_REMOVE+=("$package")
done

if [ "${#PACKAGES_TO_REMOVE[@]}" -gt 0 ]; then
    log_warn "Paquets conflictuels détectés : ${PACKAGES_TO_REMOVE[*]}"
    run_quiet "Impossible de supprimer les paquets Docker conflictuels."         apt-get remove -y "${PACKAGES_TO_REMOVE[@]}" || exit 1
else
    log_info "Aucun paquet Docker conflictuel détecté."
fi

run_quiet "Impossible de mettre à jour les dépôts APT." apt-get update || exit 1
run_quiet "Impossible d'installer les dépendances Docker."     apt-get install -y ca-certificates curl || exit 1

install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1 || {
    log_error "Impossible de créer /etc/apt/keyrings."
    exit 1
}

curl -fsSL https://download.docker.com/linux/ubuntu/gpg     -o "$DOCKER_KEYRING" >/dev/null 2>&1 || {
    log_error "Impossible de télécharger la clé GPG officielle Docker."
    log_info "Vérifiez l'accès à download.docker.com."
    exit 1
}

chmod a+r "$DOCKER_KEYRING"

cat > "$DOCKER_SOURCE" <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $UBUNTU_CODENAME
Components: stable
Architectures: $ARCH
Signed-By: $DOCKER_KEYRING
EOF

run_quiet "Impossible de mettre à jour APT après ajout du dépôt Docker."     apt-get update || exit 1

log_info "Dépôt officiel Docker configuré."
