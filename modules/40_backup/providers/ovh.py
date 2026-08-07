#!/usr/bin/env python3

"""
Client minimal OVHcloud pour le provider snapshot Server Setup.

Le client utilise le SDK officiel python-ovh et l'API VPS historique :
    GET    /vps
    GET    /vps/{serviceName}/snapshot
    POST   /vps/{serviceName}/createSnapshot
    DELETE /vps/{serviceName}/snapshot
    GET    /vps/{serviceName}/tasks/{id}

Le snapshot manuel OVH VPS est un point de restauration unique.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

import ovh


TERMINAL_OK = {"done"}
TERMINAL_ERROR = {"error", "cancelled", "canceled"}


def load_shell_config(path: str) -> dict[str, str]:
    values: dict[str, str] = {}
    pattern = re.compile(r'^([A-Z0-9_]+)="(.*)"$')

    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue

        match = pattern.match(raw)
        if not match:
            continue

        values[match.group(1)] = match.group(2)

    return values


def make_client(cfg: dict[str, str]) -> ovh.Client:
    required = (
        "OVH_ENDPOINT",
        "OVH_APPLICATION_KEY",
        "OVH_APPLICATION_SECRET",
        "OVH_CONSUMER_KEY",
    )

    missing = [key for key in required if not cfg.get(key)]
    if missing:
        raise RuntimeError(
            "Configuration OVH incomplète : " + ", ".join(missing)
        )

    return ovh.Client(
        endpoint=cfg["OVH_ENDPOINT"],
        application_key=cfg["OVH_APPLICATION_KEY"],
        application_secret=cfg["OVH_APPLICATION_SECRET"],
        consumer_key=cfg["OVH_CONSUMER_KEY"],
    )


def service_name(cfg: dict[str, str]) -> str:
    value = cfg.get("OVH_SERVICE_NAME", "")
    if not value:
        raise RuntimeError("OVH_SERVICE_NAME absent de la configuration.")
    return value


def task_id(payload) -> int | None:
    if isinstance(payload, dict) and payload.get("id") is not None:
        return int(payload["id"])
    return None


def wait_task(client: ovh.Client, service: str, payload, timeout: int = 1800) -> None:
    tid = task_id(payload)
    if tid is None:
        return

    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        task = client.get(f"/vps/{service}/tasks/{tid}")
        state = str(task.get("state", "")).lower()

        if state in TERMINAL_OK:
            return

        if state in TERMINAL_ERROR:
            raise RuntimeError(
                f"Tâche OVH {tid} terminée en erreur : "
                + json.dumps(task, ensure_ascii=False)
            )

        time.sleep(10)

    raise RuntimeError(f"Timeout sur la tâche OVH {tid}.")


def get_snapshot(client: ovh.Client, service: str):
    try:
        return client.get(f"/vps/{service}/snapshot")

    except Exception as exc:
        message = str(exc).lower()

        # OVH retourne une erreur lorsque le VPS ne possède
        # actuellement aucun snapshot.
        snapshot_missing_messages = (
            "the requested object (snapshot) does not exist",
            "requested object (snapshot) does not exist",
            "snapshot does not exist",
            "snapshot not found",
        )

        if any(value in message for value in snapshot_missing_messages):
            return None

        raise


def cmd_test(client: ovh.Client, _cfg: dict[str, str], _args) -> None:
    # /vps nécessite les droits réellement utiles au provider.
    client.get("/vps")


def cmd_list_vps(client: ovh.Client, _cfg: dict[str, str], _args) -> None:
    for service in client.get("/vps"):
        print(service)


def cmd_snapshot_exists(client: ovh.Client, cfg: dict[str, str], _args) -> None:
    snapshot = get_snapshot(client, service_name(cfg))
    raise SystemExit(0 if snapshot is not None else 3)


def cmd_get_snapshot(client: ovh.Client, cfg: dict[str, str], _args) -> None:
    snapshot = get_snapshot(client, service_name(cfg))

    if snapshot is None:
        print("Aucun snapshot OVH présent.")
        return

    print(json.dumps(snapshot, indent=2, ensure_ascii=False, sort_keys=True))


def cmd_delete_snapshot(client: ovh.Client, cfg: dict[str, str], _args) -> None:
    service = service_name(cfg)
    snapshot = get_snapshot(client, service)

    if snapshot is None:
        print("Aucun snapshot OVH à supprimer.")
        return

    payload = client.delete(f"/vps/{service}/snapshot")
    wait_task(client, service, payload)


def cmd_create_snapshot(client: ovh.Client, cfg: dict[str, str], args) -> None:
    service = service_name(cfg)

    if get_snapshot(client, service) is not None:
        raise RuntimeError(
            "Un snapshot existe déjà. Supprimez-le avant création."
        )

    print(
        f"[OVH] Création du snapshot pour {service}",
        file=sys.stderr,
    )

    try:
        payload = client.post(
            f"/vps/{service}/createSnapshot",
            description=args.description,
        )
    except Exception as exc:
        raise RuntimeError(
            f"Impossible de créer le snapshot pour {service}: "
            f"{type(exc).__name__}: {exc}"
        ) from exc

    wait_task(client, service, payload)

    for _ in range(12):
        if get_snapshot(client, service) is not None:
            print("Snapshot OVH disponible.")
            return

        time.sleep(5)

    raise RuntimeError(
        "La création est terminée mais le snapshot "
        "n'est toujours pas visible après 60 secondes."
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)

    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("test")
    sub.add_parser("list-vps")
    sub.add_parser("snapshot-exists")
    sub.add_parser("get-snapshot")
    sub.add_parser("delete-snapshot")

    create = sub.add_parser("create-snapshot")
    create.add_argument("--description", required=True)

    args = parser.parse_args()

    cfg = load_shell_config(args.config)
    client = make_client(cfg)

    commands = {
        "test": cmd_test,
        "list-vps": cmd_list_vps,
        "snapshot-exists": cmd_snapshot_exists,
        "get-snapshot": cmd_get_snapshot,
        "delete-snapshot": cmd_delete_snapshot,
        "create-snapshot": cmd_create_snapshot,
    }

    try:
        commands[args.command](client, cfg, args)
        return 0
    except SystemExit:
        raise
    except Exception as exc:
        print(
            f"[OVH][ERROR] {type(exc).__name__}: {exc}",
            file=sys.stderr,
        )

        status = getattr(exc, "http_status", None)
        if status is not None:
            print(
                f"[OVH][ERROR] HTTP status: {status}",
                file=sys.stderr,
            )

        response = getattr(exc, "response", None)
        if response is not None:
            print(
                f"[OVH][ERROR] Response: {response}",
                file=sys.stderr,
            )

        return 1


if __name__ == "__main__":
    sys.exit(main())
