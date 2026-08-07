#!/usr/bin/env bash
set -euo pipefail

provider_create_snapshot() {
    logger -t server-setup-backup \
        "Snapshot VPS manuel requis : créer un snapshot depuis le panel fournisseur."
    printf '[SNAPSHOT] Action manuelle requise : créer le snapshot VPS fournisseur.\n'
}

provider_list_snapshots() {
    printf 'La liste des snapshots est gérée depuis le panel fournisseur.\n'
}

provider_delete_snapshot() {
    printf 'La rétention des snapshots est gérée depuis le panel fournisseur.\n'
}
