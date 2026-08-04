#!/usr/bin/env bash
# Controle de droit avant execution
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

apt update && apt upgrade -y
apt install -y curl git ufw caddy
apt autoremove
