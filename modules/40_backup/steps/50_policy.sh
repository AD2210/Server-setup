#!/usr/bin/env bash
log_step "Configuration de la politique de sauvegarde"

BACKUP_CONFIG="/etc/server-setup/backup/backup.conf"
BACKUP_EXCLUDES="/etc/server-setup/backup/excludes.txt"
LOCAL_BACKUP_ROOT="/var/backups/server-setup"
HOST_ID="$(hostname -s)"

install -d -m 700 -o root -g root "/etc/server-setup/backup" "$LOCAL_BACKUP_ROOT"

REMOTE_ROOT="$(ask_input "Dossier distant racine" "servers/$HOST_ID" "REMOTE_ROOT")"
LOCAL_RETENTION_DAYS="$(ask_input "Rétention locale en jours" "3" "LOCAL_RETENTION_DAYS")"
REMOTE_RETENTION_DAYS="$(ask_input "Rétention distante en jours" "30" "REMOTE_RETENTION_DAYS")"
LOCAL_RETENTION_COUNT="$(config_get LOCAL_RETENTION_COUNT 0)"
REMOTE_RETENTION_COUNT="$(config_get REMOTE_RETENTION_COUNT 0)"
REMOTE_BACKUP_ENABLED="$(config_get REMOTE_BACKUP_ENABLED true)"
case "$REMOTE_BACKUP_ENABLED" in true | false) ;; *) log_error "REMOTE_BACKUP_ENABLED doit être true ou false."; exit 1 ;; esac
for value in "$LOCAL_RETENTION_COUNT" "$REMOTE_RETENTION_COUNT"; do
    [[ "$value" =~ ^[0-9]+$ ]] || { log_error "Nombre de sauvegardes invalide."; exit 1; }
done

for value in "$LOCAL_RETENTION_DAYS" "$REMOTE_RETENTION_DAYS"; do
    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] || {
        log_error "Rétention invalide : $value"
        exit 1
    }
done

DB_SCHEDULE="${DB_SCHEDULE:-}"
FILES_SCHEDULE="${FILES_SCHEDULE:-}"
PROVIDER_SCHEDULE="${PROVIDER_SCHEDULE:-}"

$DB_BACKUP_ENABLED && DB_SCHEDULE="$(ask_input "Fréquence des dumps PostgreSQL (OnCalendar)" "*-*-* 02,08,14,20:15:00" "DB_SCHEDULE")"
$FILES_BACKUP_ENABLED && FILES_SCHEDULE="$(ask_input "Fréquence du snapshot logique (OnCalendar)" "*-*-* 03:00:00" "FILES_SCHEDULE")"
$PROVIDER_BACKUP_ENABLED && PROVIDER_SCHEDULE="$(ask_input "Fréquence du snapshot provider (OnCalendar)" "Sun *-*-* 04:00:00" "PROVIDER_SCHEDULE")"

cat >"$BACKUP_CONFIG" <<EOF
RCLONE_CONFIG="$RCLONE_CONFIG"
RCLONE_REMOTE="$RCLONE_REMOTE"
REMOTE_ROOT="$REMOTE_ROOT"
LOCAL_BACKUP_ROOT="$LOCAL_BACKUP_ROOT"
LOCAL_RETENTION_DAYS="$LOCAL_RETENTION_DAYS"
REMOTE_RETENTION_DAYS="$REMOTE_RETENTION_DAYS"
LOCAL_RETENTION_COUNT="$LOCAL_RETENTION_COUNT"
REMOTE_RETENTION_COUNT="$REMOTE_RETENTION_COUNT"
REMOTE_BACKUP_ENABLED="$REMOTE_BACKUP_ENABLED"
HOST_ID="$HOST_ID"
DB_BACKUP_ENABLED="$DB_BACKUP_ENABLED"
FILES_BACKUP_ENABLED="$FILES_BACKUP_ENABLED"
PROVIDER_BACKUP_ENABLED="$PROVIDER_BACKUP_ENABLED"
PROVIDER_NAME="$PROVIDER_NAME"
DB_SCHEDULE="$DB_SCHEDULE"
FILES_SCHEDULE="$FILES_SCHEDULE"
PROVIDER_SCHEDULE="$PROVIDER_SCHEDULE"
EOF
chmod 600 "$BACKUP_CONFIG"

if $FILES_BACKUP_ENABLED; then
    cat >"$BACKUP_EXCLUDES" <<'EOF'
*/.git/*
*/node_modules/*
*/vendor/*
*/var/cache/*
*/var/log/*
EOF
    chmod 600 "$BACKUP_EXCLUDES"
fi

log_info "Politique de sauvegarde enregistrée."
