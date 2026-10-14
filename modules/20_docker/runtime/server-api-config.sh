#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: server-api-config CLIENT ENVIRONMENT {boost|data-suite|connector} APP_PATH\n' >&2
    exit 2
}

die() {
    printf 'API configuration error: %s\n' "$*" >&2
    exit 1
}

[[ $# -eq 4 ]] || usage
client=$1
environment=$2
role=$3
app_dir=$4
source_root=${SERVER_API_CONFIG_ROOT:-/etc/server-setup/api-config}
public_only=false
if [[ -e "$source_root/.public-only" ]]; then
    mode_file="$source_root/.public-only"
    [[ -f $mode_file && ! -L $mode_file ]] || die 'Invalid public-only mode file'
    [[ $(stat -c %u -- "$mode_file") -eq $EUID ]] || die 'Public-only mode file must be owned by the rendering user'
    mode_permissions=$(stat -c %a -- "$mode_file")
    (((8#$mode_permissions & 077) == 0)) || die 'Public-only mode file must be private'
    public_only=true
fi

[[ $client =~ ^[a-zA-Z0-9_-]+$ && $environment =~ ^[a-zA-Z0-9_-]+$ ]] || die 'Invalid client or environment name'
case $role in
    boost | data-suite | connector) ;;
    *) usage ;;
esac
[[ -d $app_dir ]] || die "Application directory not found: $app_dir"
app_dir=$(realpath -- "$app_dir")

declare -A values=()
declare -a order=()

allowed_key() {
    case "$1:$2" in
        oscar:OSCAR_BASE_URL | oscar:OSCAR_API_VERSION | oscar:OSCAR_OAUTH_GRANT | \
            oscar:OSCAR_CLIENT_ID | oscar:OSCAR_CLIENT_SECRET | oscar:OSCAR_USERNAME | \
            oscar:OSCAR_PASSWORD | oscar:OSCAR_TENANT_KEY | \
            hyperplanning:HYPERPLANNING_WSDL | hyperplanning:HYPERPLANNING_SOAP_BASE_URL | \
            hyperplanning:HYPERPLANNING_LOGIN | hyperplanning:HYPERPLANNING_PASSWORD | \
            hyperplanning:HYPERPLANNING_ACTIVE_SCHOOL_YEAR) return 0 ;;
        *) return 1 ;;
    esac
}

required_keys() {
    case $1 in
        oscar) printf '%s\n' OSCAR_BASE_URL OSCAR_CLIENT_ID OSCAR_CLIENT_SECRET OSCAR_USERNAME OSCAR_PASSWORD OSCAR_TENANT_KEY ;;
        hyperplanning) printf '%s\n' HYPERPLANNING_WSDL HYPERPLANNING_SOAP_BASE_URL HYPERPLANNING_LOGIN HYPERPLANNING_PASSWORD HYPERPLANNING_ACTIVE_SCHOOL_YEAR ;;
    esac
}

load_api() {
    local api=$1 file line key value number=0 permissions owner
    file="$source_root/$client/$environment/$api.env"
    [[ -f $file && ! -L $file ]] || die "Missing or linked inventory: $file"
    owner=$(stat -c %u -- "$file")
    [[ $owner -eq $EUID ]] || die "Inventory is not owned by the rendering user: $file"
    permissions=$(stat -c %a -- "$file")
    (((8#$permissions & 077) == 0)) || die "Inventory must be private (mode 600 or stricter): $file"
    cmp -s -- "$file" <(LC_ALL=C tr -d '\000' <"$file") || die "Inventory contains a NUL byte: $file"

    while IFS= read -r line || [[ -n $line ]]; do
        ((number += 1))
        [[ -z $line || $line == \#* ]] && continue
        [[ $line == *=* ]] || die "Malformed inventory line: $file:$number"
        key=${line%%=*}
        value=${line#*=}
        [[ $key =~ ^[A-Z][A-Z0-9_]*$ ]] && allowed_key "$api" "$key" || die "Unknown or malformed key: $file:$number"
        [[ ! -v values[$key] ]] || die "Duplicate key: $file:$number"
        [[ $value != *$'\r'* ]] || die "Invalid carriage return: $file:$number"
        values[$key]=$value
        order+=("$key")
    done <"$file"

    while IFS= read -r key; do
        [[ -n ${values[$key]:-} ]] || die "Missing required key $key in $file"
    done < <(required_keys "$api")
}

validate_hyperplanning() {
    local wsdl=${values[HYPERPLANNING_WSDL]} base=${values[HYPERPLANNING_SOAP_BASE_URL]}
    local wsdl_origin wsdl_path base_origin base_path authority port year=${values[HYPERPLANNING_ACTIVE_SCHOOL_YEAR]}
    [[ $wsdl =~ ^(https?://[^/]+)(/.+)$ ]] || die 'Invalid Hyperplanning WSDL URL'
    wsdl_origin=${BASH_REMATCH[1]}
    wsdl_path=${BASH_REMATCH[2]}
    [[ $base =~ ^(https?://[^/]+)(/.+)$ ]] || die 'Invalid Hyperplanning SOAP base URL'
    base_origin=${BASH_REMATCH[1]}
    base_path=${BASH_REMATCH[2]%/}
    [[ $wsdl_origin == "$base_origin" && $wsdl_path == "$base_path/"* ]] || die 'Hyperplanning WSDL and SOAP base must use the same public publication'
    [[ $year =~ ^([0-9]{4})-([0-9]{4})$ ]] || die 'Invalid active school year'
    ((10#${BASH_REMATCH[2]} == 10#${BASH_REMATCH[1]} + 1)) || die 'Invalid active school year'
    authority=${wsdl_origin#*://}
    case $authority in
        *:*) port=${authority##*:} ;;
        *) [[ $wsdl_origin == https://* ]] && port=443 || port=80 ;;
    esac
    case $year in
        2026-2027) [[ $port == 81 ]] || die '2026-2027 Hyperplanning publication must use port 81' ;;
        2027-2028) [[ $port == 80 ]] || die '2027-2028 Hyperplanning publication must use port 80' ;;
    esac
}

case $role in
    boost) load_api oscar ;;
    data-suite)
        load_api hyperplanning
        validate_hyperplanning
        ;;
    connector)
        load_api oscar
        load_api hyperplanning
        validate_hyperplanning
        ;;
esac

target="$app_dir/.env.api.local"
[[ ! -L $target ]] || die "Refusing linked output: $target"
temporary=$(mktemp "$app_dir/.env.api.XXXXXXXX")
trap '[[ -z ${temporary:-} ]] || rm -f -- "$temporary"' EXIT
chmod 600 -- "$temporary"
chown --reference="$app_dir" -- "$temporary"

for key in "${order[@]}"; do
    if $public_only; then
        # Credentials must already be sealed in the application's Symfony vault.
        case $key in *_PASSWORD | *_CLIENT_SECRET) continue ;; esac
    fi
    if [[ $role == boost ]]; then
        case $key in OSCAR_API_VERSION | OSCAR_OAUTH_GRANT) continue ;; esac
        output_key="OSCAR_API_${key#OSCAR_}"
    else
        output_key=$key
    fi
    printf '%s=%s\n' "$output_key" "${values[$key]}" >>"$temporary"
done

mv -f -- "$temporary" "$target"
temporary=''
printf 'Rendered %s API configuration: %s\n' "$role" "$target"
