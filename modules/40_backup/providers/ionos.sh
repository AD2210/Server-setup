#!/usr/bin/env bash
set -euo pipefail
provider_create_snapshot() { printf '[SNAPSHOT][ERROR] Adaptateur IONOS non configuré.\n' >&2; return 1; }
provider_list_snapshots() { return 1; }
provider_delete_snapshot() { return 1; }
