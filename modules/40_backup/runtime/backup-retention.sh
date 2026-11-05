#!/usr/bin/env bash
# Called only after a COMPLETE snapshot was written (and, for remote pruning,
# after rclone check). Restrict removals to our UTC timestamp directories.
retention_names() {
    local name current="$1"
    while IFS= read -r name; do
        name="${name%/}"
        [[ "$name" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || continue
        [[ "$name" > "$current" ]] && continue
        printf '%s\n' "$name"
    done | sort -r
}

prune_local_backups() {
    local prefix="$1" current="$2" keep="${LOCAL_RETENTION_COUNT:-0}" listing name index=0
    [[ "$prefix" = db || "$prefix" = files ]] || return 1
    [[ "$current" =~ ^[0-9]{8}T[0-9]{6}Z$ && "$keep" =~ ^[0-9]+$ ]] || return 1
    [[ -f "$LOCAL_BACKUP_ROOT/$prefix-$current/COMPLETE" ]] || return 1
    if ((keep == 0)); then
        find "$LOCAL_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name "$prefix-*" -mtime "+$LOCAL_RETENTION_DAYS" -exec rm -rf {} +
        return
    fi
    listing="$(find "$LOCAL_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name "$prefix-*" -printf '%f\n' | sed "s/^$prefix-//" | retention_names "$current")"
    while IFS= read -r name; do
        [[ -n "$name" && -f "$LOCAL_BACKUP_ROOT/$prefix-$name/COMPLETE" ]] || continue
        index=$((index + 1))
        if ((index > keep)) && [[ "$name" != "$current" ]]; then
            rm -rf -- "$LOCAL_BACKUP_ROOT/$prefix-$name"
        fi
    done <<<"$listing"
}

prune_remote_backups() {
    local kind="$1" current="$2" keep="${REMOTE_RETENTION_COUNT:-0}" root listing contents name index=0
    [[ "$kind" = databases || "$kind" = files ]] || return 1
    [[ "$current" =~ ^[0-9]{8}T[0-9]{6}Z$ && "$keep" =~ ^[0-9]+$ ]] || return 1
    root="${RCLONE_REMOTE}:${REMOTE_ROOT}/$kind"
    if ((keep == 0)); then
        rclone delete "$root" --config "$RCLONE_CONFIG" --min-age "${REMOTE_RETENTION_DAYS}d" --quiet
        rclone rmdirs "$root" --config "$RCLONE_CONFIG" --leave-root --quiet || true
        return
    fi
    # Capture the result first so a listing error cannot be mistaken for success.
    listing="$(rclone lsf "$root" --dirs-only --max-depth 1 --config "$RCLONE_CONFIG")" || return 1
    listing="$(retention_names "$current" <<<"$listing")"
    grep -qxF -- "$current" <<<"$listing" || return 1
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        contents="$(rclone lsf "$root/$name" --files-only --max-depth 1 --config "$RCLONE_CONFIG")" || return 1
        grep -qxF COMPLETE <<<"$contents" || continue
        index=$((index + 1))
        if ((index > keep)) && [[ "$name" != "$current" ]]; then
            rclone purge "$root/$name" --config "$RCLONE_CONFIG"
        fi
    done <<<"$listing"
}
