#!/usr/bin/env bash
set -euo pipefail
APPS_ROOT="/srv/apps"

die() {
    printf '[RELEASE][ERROR] %s\n' "$*" >&2
    exit 1
}
resolve_app_dir() { [[ "$1" = /* ]] && printf '%s\n' "$1" || printf '%s/%s\n' "$APPS_ROOT" "$1"; }
normalize_service() { printf '%s' "$1" | tr '[:lower:].-' '[:upper:]__' | tr -cd 'A-Z0-9_'; }
env_file() { printf '%s/.env.prod.local\n' "$1"; }
get_value() { sed -n -E "s/^$2=(.*)$/\\1/p" "$1" | tail -n1; }
set_value() {
    local file="$1" key="$2" value="$3" tmp
    tmp="$(mktemp)"
    awk -v key="$key" -v value="$value" '
      BEGIN{found=0}
      $0 ~ "^" key "=" { if(!found){print key "=" value; found=1}; next }
      {print}
      END{if(!found) print key "=" value}
    ' "$file" >"$tmp"
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

init_service() {
    local dir file prefix
    dir="$(resolve_app_dir "$1")"
    [ -d "$dir" ] || die "Application introuvable : $dir"
    file="$(env_file "$dir")"
    touch "$file"
    chmod 600 "$file"
    prefix="$(normalize_service "$2")"
    set_value "$file" "${prefix}_IMAGE" "$3"
    grep -q "^${prefix}_SHA_CURRENT=" "$file" || set_value "$file" "${prefix}_SHA_CURRENT" ""
    grep -q "^${prefix}_SHA_PREVIOUS=" "$file" || set_value "$file" "${prefix}_SHA_PREVIOUS" ""
}

record_release() {
    local dir file prefix current
    dir="$(resolve_app_dir "$1")"
    [ -d "$dir" ] || die "Application introuvable : $dir"
    file="$(env_file "$dir")"
    touch "$file"
    chmod 600 "$file"
    prefix="$(normalize_service "$2")"
    current="$(get_value "$file" "${prefix}_SHA_CURRENT")"
    [ -n "${4:-}" ] && set_value "$file" "${prefix}_IMAGE" "$4"
    [ "$current" = "$3" ] && {
        printf '[RELEASE] SHA déjà courant.\n'
        return
    }
    [ -n "$current" ] && set_value "$file" "${prefix}_SHA_PREVIOUS" "$current"
    set_value "$file" "${prefix}_SHA_CURRENT" "$3"
}

show_releases() {
    local dir file
    dir="$(resolve_app_dir "$1")"
    file="$(env_file "$dir")"
    [ -f "$file" ] || die "État absent : $file"
    grep -E '^([A-Z0-9_]+)_(IMAGE|SHA_CURRENT|SHA_PREVIOUS)=' "$file" || true
}

generate_env() {
    local dir file tmp line key prefix previous
    dir="$(resolve_app_dir "$1")"
    file="$(env_file "$dir")"
    [ -f "$file" ] || die "État absent : $file"
    case "$2" in
        current) cat "$file" ;;
        previous)
            tmp="$(mktemp)"
            cp "$file" "$tmp"
            while IFS= read -r line; do
                key="${line%%=*}"
                prefix="${key%_SHA_CURRENT}"
                previous="$(get_value "$file" "${prefix}_SHA_PREVIOUS")"
                [ -n "$previous" ] || die "Aucun SHA précédent pour $prefix."
                set_value "$tmp" "${prefix}_SHA_CURRENT" "$previous"
            done < <(grep -E '^[A-Z0-9_]+_SHA_CURRENT=' "$file")
            cat "$tmp"
            rm -f "$tmp"
            ;;
        *) die "Slot inconnu : $2" ;;
    esac
}

case "${1:-}" in
    init)
        [ "$#" -eq 4 ] || exit 1
        init_service "$2" "$3" "$4"
        ;;
    record)
        [ "$#" -ge 4 ] || exit 1
        record_release "$2" "$3" "$4" "${5:-}"
        ;;
    show)
        [ "$#" -eq 2 ] || exit 1
        show_releases "$2"
        ;;
    env)
        [ "$#" -eq 3 ] || exit 1
        generate_env "$2" "$3"
        ;;
    *)
        echo "Usage: server-release {init|record|show|env} ..." >&2
        exit 1
        ;;
esac
