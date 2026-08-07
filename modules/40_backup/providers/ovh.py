#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re, sys, time
from pathlib import Path
import ovh

def load_shell_config(path):
    values={}
    pat=re.compile(r'^([A-Z0-9_]+)="(.*)"$')
    for raw in Path(path).read_text().splitlines():
        m=pat.match(raw.strip())
        if m: values[m.group(1)]=m.group(2)
    return values

def make_client(c):
    return ovh.Client(endpoint=c["OVH_ENDPOINT"], application_key=c["OVH_APPLICATION_KEY"],
                      application_secret=c["OVH_APPLICATION_SECRET"], consumer_key=c["OVH_CONSUMER_KEY"])

def service_name(c):
    s=c.get("OVH_SERVICE_NAME","")
    if not s: raise RuntimeError("OVH_SERVICE_NAME absent.")
    return s

def get_snapshot(client, service):
    try:
        return client.get(f"/vps/{service}/snapshot")
    except Exception as exc:
        msg=str(exc).lower()
        if "requested object (snapshot) does not exist" in msg or "snapshot not found" in msg:
            return None
        raise

def wait_task(client, service, payload, timeout=1800):
    if not isinstance(payload, dict) or payload.get("id") is None: return
    tid=int(payload["id"]); deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        task=client.get(f"/vps/{service}/tasks/{tid}")
        state=str(task.get("state","")).lower()
        if state=="done": return
        if state in {"error","cancelled","canceled"}: raise RuntimeError(json.dumps(task))
        time.sleep(10)
    raise RuntimeError(f"Timeout tâche OVH {tid}.")

def main():
    p=argparse.ArgumentParser(); p.add_argument("--config", required=True)
    s=p.add_subparsers(dest="command", required=True)
    for x in ("test","list-vps","snapshot-exists","get-snapshot","delete-snapshot"): s.add_parser(x)
    c=s.add_parser("create-snapshot"); c.add_argument("--description", required=True)
    a=p.parse_args(); cfg=load_shell_config(a.config); client=make_client(cfg)
    try:
        if a.command=="test": client.get("/vps")
        elif a.command=="list-vps":
            for v in client.get("/vps"): print(v)
        elif a.command=="snapshot-exists":
            raise SystemExit(0 if get_snapshot(client, service_name(cfg)) else 3)
        elif a.command=="get-snapshot":
            snap=get_snapshot(client, service_name(cfg)); print(json.dumps(snap,indent=2) if snap else "Aucun snapshot OVH présent.")
        elif a.command=="delete-snapshot":
            svc=service_name(cfg); snap=get_snapshot(client,svc)
            if snap: wait_task(client,svc,client.delete(f"/vps/{svc}/snapshot"))
        elif a.command=="create-snapshot":
            svc=service_name(cfg)
            if get_snapshot(client,svc): raise RuntimeError("Un snapshot existe déjà.")
            payload=client.post(f"/vps/{svc}/createSnapshot", description=a.description)
            wait_task(client,svc,payload)
            for _ in range(12):
                if get_snapshot(client,svc): return 0
                time.sleep(5)
            raise RuntimeError("Snapshot non visible après 60 secondes.")
        return 0
    except SystemExit: raise
    except Exception as exc:
        print(f"[OVH][ERROR] {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

if __name__=="__main__":
    sys.exit(main())
