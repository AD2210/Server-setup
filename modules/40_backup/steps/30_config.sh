#!/usr/bin/env bash
## Étape 30 - Politique de sauvegarde

log_step "Configuration de la politique de sauvegarde"

BACKUP_CONFIG_DIR="/etc/server-setup/backup"
BACKUP_TARGETS_DIR="$BACKUP_CONFIG_DIR/targets.d"
BACKUP_CONFIG="$BACKUP_CONFIG_DIR/backup.conf"
BACKUP_EXCLUDES="$BACKUP_CONFIG_DIR/excludes.txt"
LOCAL_BACKUP_ROOT="/var/backups/server-setup"
HOST_ID="$(hostname -s)"

install -d -m 700 -o root -g root \
    "$BACKUP_CONFIG_DIR" "$BACKUP_TARGETS_DIR" "$LOCAL_BACKUP_ROOT"

REMOTE_ROOT="$(ask_input "Dossier distant racine" "servers/$HOST_ID")"
LOCAL_RETENTION_DAYS="$(ask_input "Rétention locale en jours" "3")"
REMOTE_RETENTION_DAYS="$(ask_input "Rétention distante en jours" "30")"
DB_SCHEDULE="$(ask_input "Fréquence dumps DB (OnCalendar)" "*-*-* 02,08,14,20:15:00")"
FILES_SCHEDULE="$(ask_input "Fréquence snapshot logique (OnCalendar)" "*-*-* 03:00:00")"
PROVIDER_SCHEDULE="$(ask_input "Fréquence snapshot VPS (OnCalendar)" "Sun *-*-* 04:00:00")"

for value in "$LOCAL_RETENTION_DAYS" "$REMOTE_RETENTION_DAYS"; do
    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] || {
        log_error "Rétention invalide : $value"
        exit 1
    }
done

cat > "$BACKUP_CONFIG" <<EOF
RCLONE_CONFIG="$RCLONE_CONFIG"
RCLONE_REMOTE="$RCLONE_REMOTE"
REMOTE_ROOT="$REMOTE_ROOT"
LOCAL_BACKUP_ROOT="$LOCAL_BACKUP_ROOT"
LOCAL_RETENTION_DAYS="$LOCAL_RETENTION_DAYS"
REMOTE_RETENTION_DAYS="$REMOTE_RETENTION_DAYS"
HOST_ID="$HOST_ID"
EOF
chmod 600 "$BACKUP_CONFIG"

cat > "$BACKUP_EXCLUDES" <<'EOF'
*/.git/*
*/node_modules/*
*/vendor/*
*/var/cache/*
*/var/log/*
*/data/*
*/volumes/*
EOF
chmod 600 "$BACKUP_EXCLUDES"

log_info "Politique de sauvegarde enregistrée."
