#!/usr/bin/env bash
# Read-only inventory for an unstandardized ITC VPS. Never prints environment values.
set -u
section() { printf '\n## %s\n' "$1"; }
run() { "$@" 2>&1 || printf '[unavailable] %s\n' "$1"; }

section 'Identity and OS'
run hostname
run id -un
if [ -r /etc/os-release ]; then
    sed -n -E '/^(ID|VERSION_ID|PRETTY_NAME)=/p' /etc/os-release
fi
run uname -r

section 'Filesystems and free space'
if command -v findmnt >/dev/null 2>&1; then
    for target in / /boot /boot/efi /srv /var/lib/docker; do
        [ -e "$target" ] && findmnt -n -T "$target" -o SOURCE,TARGET,FSTYPE 2>/dev/null || true
    done
fi
if command -v lsblk >/dev/null 2>&1; then
    run lsblk -e7 -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS
fi
run df -hT / /srv /var/lib/docker

section 'Docker runtime'
if command -v docker >/dev/null 2>&1; then
    run docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'
    run docker compose version
    run docker compose ls --all
    run docker ps -a --format 'name={{.Names}} image={{.Image}} status={{.Status}} ports={{.Ports}} project={{.Label "com.docker.compose.project"}}'
    run docker volume ls --format 'name={{.Name}} driver={{.Driver}}'
    section 'Container mounts (paths and volume names only)'
    ids="$(docker ps -aq 2>/dev/null || true)"
    if [ -n "$ids" ]; then
        # Restrict inspect output to mounts; never emit .Config.Env or labels.
        docker inspect --format '{{.Name}}{{range .Mounts}}{{printf "\n  type=%s name=%s source=%s target=%s" .Type .Name .Source .Destination}}{{end}}{{println}}' $ids 2>&1 || true
    fi
fi

section 'Applications and configuration paths'
for path in /srv/app /srv/apps /opt/server-setup /opt/Server-setup /etc/caddy /etc/itc /etc/server-setup /var/backups /var/lib/docker/volumes; do
    if [ -e "$path" ]; then
        stat -c '%n type=%F owner=%U:%G mode=%a' "$path"
        find "$path" -mindepth 1 -maxdepth 2 \( -name '.env*' -o -name '*secret*' -o -name '*password*' \) -prune -o -mindepth 1 -maxdepth 2 -type d -printf '%p\n' 2>/dev/null | head -80
    fi
done

section 'Relevant services and listeners'
if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --all --type=service --no-pager --no-legend 2>/dev/null | awk '$1 ~ /^(docker|containerd|caddy|postgres|nginx|apache|server-setup)/ {print $1, $3, $4}'
    systemctl list-timers --all --no-pager --no-legend 2>/dev/null | awk '$0 ~ /(backup|snapshot|server-setup|certbot)/ {print $0}'
fi
if command -v ss >/dev/null 2>&1; then
    ss -ltnH 2>/dev/null | awk '{print $4}' | sort -u
fi

section 'Backup files (metadata only)'
for path in /var/backups/server-setup /var/backups /srv/backup /srv/backups; do
    if [ -d "$path" ]; then
        find "$path" -mindepth 1 -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | head -60
    fi
done
