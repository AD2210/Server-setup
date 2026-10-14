#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
renderer="$script_dir/../modules/20_docker/runtime/server-api-config.sh"
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
export SERVER_API_CONFIG_ROOT="$temporary/sources"
source_dir="$SERVER_API_CONFIG_ROOT/client/preprod"
mkdir -p "$source_dir" "$temporary/boost" "$temporary/data-suite" "$temporary/connector"
umask 077

cat >"$source_dir/oscar.env" <<'ENV'
OSCAR_BASE_URL=https://oscar.example.invalid
OSCAR_CLIENT_ID=123
OSCAR_CLIENT_SECRET=oscar-$secret
OSCAR_USERNAME=user@example.invalid
OSCAR_PASSWORD=password!$with-special
OSCAR_TENANT_KEY=client
ENV
cat >"$source_dir/hyperplanning.env" <<'ENV'
HYPERPLANNING_WSDL=https://hp.example.invalid:81/hpsw/wsdl/RpcEncoded
HYPERPLANNING_SOAP_BASE_URL=https://hp.example.invalid:81/hpsw
HYPERPLANNING_LOGIN=login
HYPERPLANNING_PASSWORD=hp-$secret
HYPERPLANNING_ACTIVE_SCHOOL_YEAR=2026-2027
ENV

fail() {
    printf 'FAIL: %s\n' "$*" >&2; exit 1
}
expect_line() { grep -Fxq -- "$2" "$1" || fail "Missing expected line in $1"; }
expect_absent() { ! grep -Fq -- "$2" "$1" || fail "Unexpected API key in $1"; }

for role in boost data-suite connector; do
    bash "$renderer" client preprod "$role" "$temporary/$role" >/dev/null
    output="$temporary/$role/.env.api.local"
    [[ $(stat -c %a -- "$output") == 600 ]] || fail "Output permissions for $role"
    case $role in
        boost)
            expect_line "$output" 'OSCAR_API_CLIENT_SECRET=oscar-$secret'
            expect_absent "$output" HYPERPLANNING_
            ;;
        data-suite)
            expect_line "$output" 'HYPERPLANNING_PASSWORD=hp-$secret'
            expect_absent "$output" OSCAR_
            ;;
        connector)
            expect_line "$output" 'OSCAR_CLIENT_SECRET=oscar-$secret'
            expect_line "$output" 'HYPERPLANNING_PASSWORD=hp-$secret'
            ;;
    esac
done

touch "$SERVER_API_CONFIG_ROOT/.public-only"
chmod 600 "$SERVER_API_CONFIG_ROOT/.public-only"
for role in boost data-suite connector; do
    bash "$renderer" client preprod "$role" "$temporary/$role" >/dev/null
    expect_absent "$temporary/$role/.env.api.local" PASSWORD
    expect_absent "$temporary/$role/.env.api.local" CLIENT_SECRET
done
rm "$SERVER_API_CONFIG_ROOT/.public-only"
for role in boost data-suite connector; do
    bash "$renderer" client preprod "$role" "$temporary/$role" >/dev/null
done

printf 'prior-version\n' >"$temporary/boost/.env.api.local"
printf 'UNEXPECTED_SECRET=bad\n' >>"$source_dir/oscar.env"
if bash "$renderer" client preprod boost "$temporary/boost" >/dev/null 2>&1; then
    fail 'Unknown inventory key was accepted'
fi
expect_line "$temporary/boost/.env.api.local" 'prior-version'

sed -i '/^UNEXPECTED_SECRET=/d' "$source_dir/oscar.env"
chmod 644 "$source_dir/oscar.env"
if bash "$renderer" client preprod connector "$temporary/connector" >/dev/null 2>&1; then
    fail 'World-readable inventory was accepted'
fi

chmod 600 "$source_dir/oscar.env"
sed -i 's/:81\//:80\//g' "$source_dir/hyperplanning.env"
if bash "$renderer" client preprod data-suite "$temporary/data-suite" >/dev/null 2>&1; then
    fail 'A school year and port mismatch was accepted'
fi
expect_line "$temporary/data-suite/.env.api.local" 'HYPERPLANNING_ACTIVE_SCHOOL_YEAR=2026-2027'

printf 'OK: API inventory rendering, separation, atomicity, year and permissions\n'
