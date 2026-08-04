#!/usr/bin/env bash
# Controle de droit avant execution
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en root (sudo)"
  exit 1
fi

apt update && apt upgrade -y
apt install -y curl git ufw caddy
apt autoremove
