#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$BASE_DIR/lib/log.sh"
source "$BASE_DIR/lib/prompt.sh"

# configuration ssh
log_info "Mise à Jour de la configuration SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
update_sshd_config() {
  local key="$1"
  local value="$2"
  local file="/etc/ssh/sshd_config"

  if grep -qE "^[#]*\s*$key" "$file"; then
    sed -i "s|^[#]*\s*$key.*|$key $value|" "$file"
  else
    echo "$key $value" >> "$file"
  fi
} 
log_info "Configuration port SSH..."

SSH_PORT=$(ask_input "Enter SSH port" "22")

if [ -z "$SSH_PORT" ]; then
  log_error "SSH port cannot be empty"
  exit 1
fi

if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
  log_error "Invalid SSH port: $SSH_PORT"
  exit 1
fi

update_sshd_config "Port" "$SSH_PORT"
update_sshd_config "PermitRootLogin" "no"
update_sshd_config "PasswordAuthentication" "no"

if ! sshd -t; then
  log_error "SSH config invalid, restoring backup"
  cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
  exit 1
fi
systemctl restart ssh

# Config du parefeu


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