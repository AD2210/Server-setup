#!/usr/bin/env bash
set -euo pipefail
provider_create_snapshot() {
    logger -t server-setup-backup "Snapshot VPS manuel requis."
    printf '[SNAPSHOT] Action manuelle requise.\n'
}
provider_list_snapshots() { printf 'Gestion via panel fournisseur.\n'; }
provider_delete_snapshot() { printf 'Gestion via panel fournisseur.\n'; }
