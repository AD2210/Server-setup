#!/usr/bin/env bash
log_step "Installation des snippets Caddy partagés"

install -d -m 755 /etc/caddy/apps /etc/caddy/snippets
install -d -m 750 -o caddy -g caddy /var/log/caddy
if [[ ! -e /var/log/caddy/access.log ]]; then
    install -m 640 -o caddy -g caddy /dev/null /var/log/caddy/access.log
else
    chown caddy:caddy /var/log/caddy/access.log
    chmod 640 /var/log/caddy/access.log
fi
for snippet in security logging; do
    install -m 644 "$PROJECT_DIR/config/caddy/snippets/$snippet.caddy" \
        "/etc/caddy/snippets/$snippet.caddy"
done

if [[ "${CADDY_REPLACE_GLOBAL:-false}" == true ]]; then
    # Existing site blocks must have been migrated to apps/*.caddy first.
    shared_backup="$CADDYFILE.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    cp -a "$CADDYFILE" "$shared_backup"
    cat "$PROJECT_DIR/config/Caddyfile.template" > "$CADDYFILE"
    if ! caddy validate --config "$CADDYFILE" --adapter caddyfile \
        || ! systemctl reload caddy; then
        cat "$shared_backup" > "$CADDYFILE"
        systemctl reload caddy || true
        log_error "Configuration Caddy partagée refusée ; configuration précédente restaurée."
        exit 1
    fi
fi

log_info "Snippets security/logging installés dans /etc/caddy/snippets."
