#!/usr/bin/env bash
set -euo pipefail

provider_create_snapshot() {
    printf '[SNAPSHOT][ERROR] Adaptateur OVH non configuré.\n' >&2
    printf '[SNAPSHOT] Utilisez provider=manual ou implémentez l’API OVH validée pour votre offre VPS.\n' >&2
    return 1
}

provider_list_snapshots() {
    printf '[SNAPSHOT][ERROR] Adaptateur OVH non configuré.\n' >&2
    return 1
}

provider_delete_snapshot() {
    printf '[SNAPSHOT][ERROR] Adaptateur OVH non configuré.\n' >&2
    return 1
}
