#!/usr/bin/env bash
# Ubuntu's Caddy package can predate the shared template's global options.
# Use the stable repository documented at https://caddyserver.com/docs/install.
log_step "Préparation du dépôt stable officiel Caddy"
run_quiet "Impossible d'installer les dépendances du dépôt Caddy." \
    apt-get install -y ca-certificates curl gnupg || exit 1
caddy_repo_tmp="$(mktemp -d)"
if ! curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    -o "$caddy_repo_tmp/gpg.key" ||
    ! curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
        -o "$caddy_repo_tmp/caddy-stable.list"; then
    rm -rf "$caddy_repo_tmp"
    log_error "Impossible de télécharger la configuration officielle Caddy."
    exit 1
fi
if ! gpg --batch --yes --dearmor -o "$caddy_repo_tmp/caddy.gpg" "$caddy_repo_tmp/gpg.key"; then
    rm -rf "$caddy_repo_tmp"
    log_error "Clé du dépôt Caddy invalide."
    exit 1
fi
install -m 644 "$caddy_repo_tmp/caddy.gpg" /usr/share/keyrings/caddy-stable-archive-keyring.gpg
install -m 644 "$caddy_repo_tmp/caddy-stable.list" /etc/apt/sources.list.d/caddy-stable.list
rm -rf "$caddy_repo_tmp"
run_quiet "Impossible de charger le dépôt officiel Caddy." apt-get update || exit 1
log_info "Dépôt stable officiel Caddy configuré."
