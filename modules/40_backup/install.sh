#!/usr/bin/env bash
apt install -y rsnapshot
mkdir -p /backup
cat <<EOF > /etc/cron.daily/backup
#!/bin/bash
tar -czf /backup/system-$(date +%F).tar.gz /etc /opt
EOF
chmod +x /etc/cron.daily/backup
