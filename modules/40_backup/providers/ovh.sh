#!/usr/bin/env bash

## ============================================================================
## Provider snapshot OVHcloud
##
## Interface commune :
## - provider_create_snapshot
## - provider_list_snapshots
## - provider_delete_snapshot
##
## OVH VPS ne conserve qu'un snapshot manuel à la fois.
## ============================================================================

set -euo pipefail

OVH_CONFIG="/etc/server-setup/backup/providers/ovh.conf"
OVH_VENV="/var/lib/server-setup/providers/ovh-venv"
OVH_CLIENT="/usr/local/lib/server-setup/ovh-provider.py"

provider_require_runtime() {
    [ -r "$OVH_CONFIG" ] || {
        printf '[SNAPSHOT][ERROR] Configuration OVH absente : %s\n' "$OVH_CONFIG" >&2
        return 1
    }

    [ -x "$OVH_VENV/bin/python" ] || {
        printf '[SNAPSHOT][ERROR] Virtualenv OVH absent.\n' >&2
        return 1
    }

    [ -x "$OVH_CLIENT" ] || {
        printf '[SNAPSHOT][ERROR] Client OVH absent.\n' >&2
        return 1
    }
}

provider_create_snapshot() {
    provider_require_runtime || return 1

    local description
    description="server-setup-$(date -u +%Y%m%dT%H%M%SZ)"

    printf '[SNAPSHOT] Vérification du snapshot OVH existant.\n'

    if "$OVH_VENV/bin/python" "$OVH_CLIENT" \
        --config "$OVH_CONFIG" snapshot-exists; then

        printf '[SNAPSHOT] Suppression du snapshot OVH précédent.\n'

        "$OVH_VENV/bin/python" "$OVH_CLIENT" \
            --config "$OVH_CONFIG" delete-snapshot \
            || return 1
    fi

    printf '[SNAPSHOT] Création du snapshot OVH : %s\n' "$description"

    "$OVH_VENV/bin/python" "$OVH_CLIENT" \
        --config "$OVH_CONFIG" create-snapshot \
        --description "$description" \
        || return 1

    printf '[SNAPSHOT] Snapshot OVH créé avec succès.\n'
}

provider_list_snapshots() {
    provider_require_runtime || return 1

    "$OVH_VENV/bin/python" "$OVH_CLIENT" \
        --config "$OVH_CONFIG" get-snapshot
}

provider_delete_snapshot() {
    provider_require_runtime || return 1

    "$OVH_VENV/bin/python" "$OVH_CLIENT" \
        --config "$OVH_CONFIG" delete-snapshot
}
