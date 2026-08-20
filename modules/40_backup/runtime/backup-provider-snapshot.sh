#!/usr/bin/env bash
set -euo pipefail
PROVIDER="/usr/local/lib/server-setup/provider-snapshot.sh"
[ -x "$PROVIDER" ] || {
    printf '[SNAPSHOT][ERROR] Provider snapshot absent.\n' >&2
    exit 1
}
source "$PROVIDER"
provider_create_snapshot
