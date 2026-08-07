#!/usr/bin/env bash
## Étape 70 - Services et timers systemd

log_step "Configuration des timers de sauvegarde"

create_service() {
    local name="$1" description="$2" exec="$3" docker_dependency="${4:-no}"

    {
        echo "[Unit]"
        echo "Description=$description"
        echo "Wants=network-online.target"
        echo "After=network-online.target"
        if [ "$docker_dependency" = "yes" ]; then
            echo "Wants=docker.service"
            echo "After=docker.service"
        fi
        echo
        echo "[Service]"
        echo "Type=oneshot"
        echo "User=root"
        echo "Group=root"
        echo "ExecStart=$exec"
        echo "Nice=10"
        echo "IOSchedulingClass=best-effort"
        echo "IOSchedulingPriority=7"
    } > "/etc/systemd/system/$name.service"
}

create_timer() {
    local name="$1" description="$2" schedule="$3"

    cat > "/etc/systemd/system/$name.timer" <<EOF
[Unit]
Description=$description

[Timer]
OnCalendar=$schedule
Persistent=true
RandomizedDelaySec=10m
Unit=$name.service

[Install]
WantedBy=timers.target
EOF
}

create_service \
    "server-setup-backup-db" \
    "Server Setup - Sauvegarde PostgreSQL" \
    "/usr/local/lib/server-setup/backup-databases.sh" \
    "yes"

create_timer \
    "server-setup-backup-db" \
    "Server Setup - Timer PostgreSQL" \
    "$DB_SCHEDULE"

create_service \
    "server-setup-backup-files" \
    "Server Setup - Snapshot logique fichiers" \
    "/usr/local/lib/server-setup/backup-files.sh"

create_timer \
    "server-setup-backup-files" \
    "Server Setup - Timer fichiers" \
    "$FILES_SCHEDULE"

create_service \
    "server-setup-backup-provider" \
    "Server Setup - Snapshot VPS fournisseur" \
    "/usr/local/lib/server-setup/backup-provider-snapshot.sh"

create_timer \
    "server-setup-backup-provider" \
    "Server Setup - Timer snapshot VPS" \
    "$PROVIDER_SCHEDULE"

run_quiet "Impossible de recharger systemd." systemctl daemon-reload || exit 1

for timer in \
    server-setup-backup-db.timer \
    server-setup-backup-files.timer \
    server-setup-backup-provider.timer; do

    run_quiet "Impossible d'activer $timer." systemctl enable --now "$timer" || exit 1
done

log_info "Timers de sauvegarde activés."
