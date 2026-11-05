#!/usr/bin/env bash
# Administrator workstation pull; the SSH private key stays on this workstation.
set -euo pipefail
umask 077
# The caller supplies a trusted, workstation-local configuration file.
# shellcheck disable=SC1090
source "${1:?Configuration file required}"
: "${BACKUP_HOST:?}" "${BACKUP_USER:?}" "${BACKUP_PORT:?}"
: "${BACKUP_KEY:?}" "${BACKUP_KNOWN_HOSTS:?}" "${BACKUP_MOUNT:?}" "${BACKUP_DEST:?}"
[[ "$BACKUP_DEST" = "$BACKUP_MOUNT/"* ]] || exit 2
mountpoint -q "$BACKUP_MOUNT" || {
    echo 'Backup disk is not mounted.' >&2
    exit 1
}
mkdir -p "$BACKUP_DEST"
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/server-backup-pull-${UID}.lock"
flock -n 9 || exit 0
ssh_args=(-F /dev/null -i "$BACKUP_KEY" -p "$BACKUP_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$BACKUP_KNOWN_HOSTS" -o ConnectTimeout=15)
remote="$BACKUP_USER@$BACKUP_HOST"
manifest="$(ssh "${ssh_args[@]}" "$remote" 'sudo -n server-backup-export --manifest' </dev/null)"
if [[ -s "$BACKUP_DEST/latest.tar.gz" && -s "$BACKUP_DEST/latest.manifest" && -s "$BACKUP_DEST/latest.sha256" ]] &&
    cmp -s "$BACKUP_DEST/latest.manifest" <(printf '%s\n' "$manifest") &&
    (cd "$BACKUP_DEST" && sha256sum -c latest.sha256 >/dev/null 2>&1); then
    echo 'Latest complete backup already present and checksum verified.'
    exit 0
fi
cache="${BACKUP_CACHE:-$HOME/.cache/server-backup-pull}"
install -d -m 700 "$cache"
work="$(mktemp -d "$cache/pull.XXXXXX")"
trap 'rm -rf "$work"' EXIT
ssh "${ssh_args[@]}" "$remote" 'sudo -n server-backup-export --archive' </dev/null >"$work/backup.tar.gz"
python3 - "$work" <<'PY'
import hashlib, pathlib, re, sys, tarfile
work = pathlib.Path(sys.argv[1])
extract = work / 'verified'
extract.mkdir(mode=0o700)
with tarfile.open(work / 'backup.tar.gz') as archive:
    members = archive.getmembers()
    for member in members:
        parts = pathlib.PurePosixPath(member.name).parts
        if not parts or not re.fullmatch(r'(db|files)-[0-9]{8}T[0-9]{6}Z', parts[0]):
            raise RuntimeError('Unexpected backup member')
        if '..' in parts or not (member.isfile() or member.isdir()):
            raise RuntimeError('Unsafe backup member')
    archive.extractall(extract, members=members, filter='data')
snapshots = sorted(extract.iterdir())
if len(snapshots) != 2 or {p.name.split('-', 1)[0] for p in snapshots} != {'db', 'files'}:
    raise RuntimeError('A database and files snapshot are required')
for snapshot in snapshots:
    if not (snapshot / 'COMPLETE').is_file():
        raise RuntimeError('Incomplete snapshot')
    lines = (snapshot / 'SHA256SUMS').read_text().splitlines()
    if not lines:
        raise RuntimeError('Empty checksum manifest')
    for line in lines:
        expected, name = line.split(maxsplit=1)
        name = name.lstrip('*')
        path = snapshot / name
        if not path.resolve().is_relative_to(snapshot.resolve()):
            raise RuntimeError('Checksum path escapes snapshot')
        with path.open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        if actual != expected:
            raise RuntimeError('Snapshot checksum mismatch')
with (work / 'manifest').open('w') as output:
    for snapshot in snapshots:
        digest = hashlib.sha256((snapshot / 'SHA256SUMS').read_bytes()).hexdigest()
        output.write(f'{digest}  {snapshot.name}/SHA256SUMS\n')
PY
cp "$work/backup.tar.gz" "$BACKUP_DEST/latest.tar.gz.partial"
cmp "$work/backup.tar.gz" "$BACKUP_DEST/latest.tar.gz.partial"
mv "$BACKUP_DEST/latest.tar.gz.partial" "$BACKUP_DEST/latest.tar.gz"
cp "$work/manifest" "$BACKUP_DEST/latest.manifest"
(cd "$BACKUP_DEST" && sha256sum latest.tar.gz >latest.sha256)
echo "Latest backup copied and verified: $BACKUP_DEST/latest.tar.gz"
