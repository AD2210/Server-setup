#!/usr/bin/env bash
mkdir -p /opt/caddy
cp ../../config/Caddyfile.template /opt/caddy/Caddyfile
cat <<EOF > /opt/caddy/docker-compose.yml
version: '3'
services:
  caddy:
    image: caddy:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
volumes:
  caddy_data:
EOF
cd /opt/caddy && docker compose up -d
