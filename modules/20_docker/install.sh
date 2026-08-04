#!/usr/bin/env bash
if ! command -v docker >/dev/null; then
  apt install -y docker.io docker-compose-plugin
  systemctl enable docker
  systemctl start docker
fi
