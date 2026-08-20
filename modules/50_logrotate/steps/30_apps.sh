#!/usr/bin/env bash
log_step "Détection des logs applicatifs"

APPS_DIR="/srv/apps"
APP_ROTATE="/etc/logrotate.d/server-setup-apps"

if [ ! -d "$APPS_DIR" ]; then
    log_info "Aucun dossier /srv/apps : rotation applicative ignorée."
    return 0 2>/dev/null || true
fi

# Les logs Symfony standardisés sous var/log sont pris en charge.
cat >"$APP_ROTATE" <<'EOF'
/srv/apps/*/var/log/*.log {
    daily
    rotate 14
    size 50M
    missingok
    notifempty
    compress
    delaycompress
    dateext
    copytruncate
}
EOF
chmod 644 "$APP_ROTATE"

log_info "Rotation des logs applicatifs configurée."
log_info "Les logs Docker restent gérés par daemon.json."
