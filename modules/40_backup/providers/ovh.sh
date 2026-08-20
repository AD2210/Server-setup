#!/usr/bin/env bash
set -euo pipefail

OVH_CONFIG="/etc/server-setup/backup/providers/ovh.conf"
OVH_VENV="/var/lib/server-setup/providers/ovh-venv"
OVH_CLIENT="/usr/local/lib/server-setup/ovh-provider.py"

provider_require_runtime() {
    [ -r "$OVH_CONFIG" ] && [ -x "$OVH_VENV/bin/python" ] && [ -x "$OVH_CLIENT" ]
}

provider_create_snapshot() {
    provider_require_runtime || return 1
    local description
    description="server-setup-$(date -u +%Y%m%dT%H%M%SZ)"

    printf '[SNAPSHOT] Vérification du snapshot OVH existant.\n'
    if "$OVH_VENV/bin/python" "$OVH_CLIENT" --config "$OVH_CONFIG" snapshot-exists; then
        printf '[SNAPSHOT] Suppression du snapshot OVH précédent.\n'
        "$OVH_VENV/bin/python" "$OVH_CLIENT" --config "$OVH_CONFIG" delete-snapshot || return 1
    fi

    printf '[SNAPSHOT] Création du snapshot OVH : %s\n' "$description"
    "$OVH_VENV/bin/python" "$OVH_CLIENT" --config "$OVH_CONFIG" create-snapshot --description "$description"
}

provider_list_snapshots() {
    provider_require_runtime || return 1
    "$OVH_VENV/bin/python" "$OVH_CLIENT" --config "$OVH_CONFIG" get-snapshot
}

provider_delete_snapshot() {
    provider_require_runtime || return 1
    "$OVH_VENV/bin/python" "$OVH_CLIENT" --config "$OVH_CONFIG" delete-snapshot
}
