#!/usr/bin/env bash
apt install -y fail2ban
cp ../../config/sshd_config.template /etc/ssh/sshd_config
systemctl restart ssh
ufw default deny incoming
ufw default allow outgoing
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable
cp ../../config/jail.local /etc/fail2ban/jail.local
systemctl restart fail2ban
