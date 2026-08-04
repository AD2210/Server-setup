#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$BASE_DIR/lib/log.sh"
source "$BASE_DIR/lib/prompt.sh"

# configuration ssh
log_info "Mise à Jour de la configuration SSH..."

sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config || echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl restart ssh

# Config du parefeu
log_info "Configuration port SSH..."

SSH_PORT=$(ask_input "Enter SSH port" "22")

log_info "Port UFW ouvert pour connexion ssh : $SSH_PORT"
ufw allow "$SSH_PORT"/tcp

# garder 22 temporairement ouvert
ufw allow 22/tcp

# configuration de base (80 http et 443 https)
ufw default deny incoming
ufw default allow outgoing
ufw allow 80
ufw allow 443
ufw --force enable

# instalation Fail2ban
apt install -y fail2ban
cp ../../config/jail.local /etc/fail2ban/jail.local
systemctl restart fail2ban

# fermeture du port par défaut
log_warn "--------------------------------------------------"
log_warn "IMPORTANT: Port SSH modifié"
log_warn "Avant de fermer le port 22:"
log_warn "1. Ouvrir un nouveau terminal"
log_warn "2. Tester la connexion avec le nouveau port : ssh -p [port] [user]@[ip]"
log_warn "3. Vérifier que la connexion reussi"
log_warn "--------------------------------------------------"

if confirm "Voulez vous fermer le port 22 maintenant ?"; then
  log_info "Fermeture du port 22 dans UFW..."
  ufw delete allow 22/tcp
else
  log_info "Port 22 toujours ouvert"
fi