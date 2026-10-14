#!/usr/bin/env bash
# Sauvegarde ITC à lancer depuis le poste opérateur, sans écriture sur le VPS.
set -euo pipefail
umask 077

remote='root@87.106.26.105'
ssh_opts=(-T -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -p 55122)
backup_root="${ITC_BACKUP_ROOT:-$HOME/backup/itc}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$backup_root/$stamp"
install -d -m 700 "$backup_root"
exec 9>"$backup_root/.backup.lock"
flock -n 9 || {
    printf 'Une autre sauvegarde ITC est deja en cours.\n' >&2; exit 1
}
install -d -m 700 "$backup_dir"

capture() {
    local name="$1" remote_command="$2"
    printf 'Capture %s\n' "$name"
    ssh "${ssh_opts[@]}" "$remote" "$remote_command" >"$backup_dir/$name.partial"
    test -s "$backup_dir/$name.partial"
    mv -- "$backup_dir/$name.partial" "$backup_dir/$name"
    chmod 600 "$backup_dir/$name"
}

capture boost-prod.dump \
    'docker exec boost-database-1 sh -c '\''exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc'\'''
capture boost-globals.sql \
    'docker exec boost-database-1 sh -c '\''exec pg_dumpall -U "$POSTGRES_USER" --globals-only'\'''
capture data-suite-beta.dump \
    'docker exec itc-cfa-opco-beta-database-1 sh -c '\''exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc'\'''
capture data-suite-globals.sql \
    'docker exec itc-cfa-opco-beta-database-1 sh -c '\''exec pg_dumpall -U "$POSTGRES_USER" --globals-only'\'''
capture data-suite-documents.tar \
    'tar --acls --xattrs --numeric-owner -C / -cpf - srv/app/data-suite/var/storage'
capture server-configuration.tar.gz \
    'tar --acls --xattrs --numeric-owner --exclude=srv/app/data-suite/var/storage -C / -czpf - etc srv/app/boost srv/app/data-suite root/.config/rclone'
capture caddy-runtime.tar.gz \
    'tar --acls --xattrs --numeric-owner -C / -czpf - var/lib/docker/volumes/boost_caddy_config/_data var/lib/docker/volumes/boost_caddy_data/_data var/lib/docker/volumes/itc-cfa-opco-beta_caddy_config/_data var/lib/docker/volumes/itc-cfa-opco-beta_caddy_data/_data'
capture installed-packages.txt 'dpkg-query -W'

ssh "${ssh_opts[@]}" "$remote" 'bash -s' \
    </home/andel/.local/lib/itc-migration/audit-readonly.sh \
    >"$backup_dir/server-inventory.txt.partial"
test -s "$backup_dir/server-inventory.txt.partial"
mv -- "$backup_dir/server-inventory.txt.partial" "$backup_dir/server-inventory.txt"
chmod 600 "$backup_dir/server-inventory.txt"

install -m 600 /home/andel/DevOps/server-setup/docs/ITC_THREE_APP_MIGRATION.md \
    "$backup_dir/MIGRATION_PLAN.md"

consistency_note='Sauvegarde sans gel des ecritures ; ne pas utiliser comme point final synchronise de migration.'
if [[ "${ITC_WRITES_PAUSED:-0}" == 1 ]]; then
    consistency_note='Services PHP, messenger et scheduler arretes sur les deux stacks pendant toute la capture ; bases restees actives.'
fi
cat >"$backup_dir/README.txt" <<EOF
Capture UTC: $stamp
Source: VPS ITC 87.106.26.105
Bases: boost production et data-suite beta, dumps PostgreSQL custom et roles globaux.
Documents: /srv/app/data-suite/var/storage actif uniquement.
Configuration: /etc, deux dossiers applicatifs hors documents, rclone, volumes Caddy.
Inventaire: paquets installes et audit technique du VPS en lecture seule.
MIGRATION_PLAN.md: déroulé et portes de validation pour l'intervention du soir.
Ancien volume documentaire non monte: exclu a la demande du proprietaire.
$consistency_note
Le dossier contient des secrets et des empreintes de mots de passe ; chiffrer toute autre copie.
EOF
chmod 600 "$backup_dir/README.txt"

(
    cd "$backup_dir"
    tar -tf data-suite-documents.tar >/dev/null
    tar -tzf server-configuration.tar.gz >/dev/null
    tar -tzf caddy-runtime.tar.gz >/dev/null
    for dump in boost-prod.dump data-suite-beta.dump; do
        docker run --rm --network none --mount "type=bind,src=$backup_dir,dst=/backup,readonly" \
            --entrypoint pg_restore postgres:16-alpine --list "/backup/$dump" >/dev/null
    done
    sha256sum boost-prod.dump boost-globals.sql data-suite-beta.dump data-suite-globals.sql \
        data-suite-documents.tar server-configuration.tar.gz caddy-runtime.tar.gz \
        installed-packages.txt server-inventory.txt MIGRATION_PLAN.md README.txt >SHA256SUMS
    chmod 600 SHA256SUMS
    sha256sum --check SHA256SUMS
)
printf 'Sauvegarde terminee : %s\n' "$backup_dir"
