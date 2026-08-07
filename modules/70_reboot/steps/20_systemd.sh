#!/usr/bin/env bash
log_step "Création du timer de redémarrage"

SERVICE="/etc/systemd/system/server-setup-reboot.service"
TIMER="/etc/systemd/system/server-setup-reboot.timer"

cat > "$SERVICE" <<'EOF'
[Unit]
Description=Server Setup - Redémarrage périodique

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl reboot
EOF

cat > "$TIMER" <<EOF
[Unit]
Description=Server Setup - Timer de redémarrage périodique

[Timer]
OnCalendar=$REBOOT_SCHEDULE
Persistent=false
AccuracySec=1min
Unit=server-setup-reboot.service

[Install]
WantedBy=timers.target
EOF

run_quiet "Impossible de recharger systemd." systemctl daemon-reload || exit 1
run_quiet "Impossible d'activer le timer de reboot." \
    systemctl enable --now server-setup-reboot.timer || exit 1

log_info "Timer de redémarrage activé."
