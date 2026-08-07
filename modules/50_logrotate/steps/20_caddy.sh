#!/usr/bin/env bash
log_step "Configuration de la rotation des logs Caddy"

CADDY_LOG_DIR="/var/log/caddy"
CADDY_ROTATE="/etc/logrotate.d/server-setup-caddy"

if [ -d "$CADDY_LOG_DIR" ]; then
    cat > "$CADDY_ROTATE" <<'EOF'
/var/log/caddy/*.log {
    daily
    rotate 14
    size 50M
    missingok
    notifempty
    compress
    delaycompress
    dateext
    create 0640 caddy caddy
    sharedscripts
    postrotate
        /bin/systemctl reload caddy >/dev/null 2>&1 || true
    endscript
}
EOF
    chmod 644 "$CADDY_ROTATE"
    log_info "Rotation Caddy configurée."
else
    log_info "Aucun répertoire /var/log/caddy : configuration Caddy ignorée."
fi
