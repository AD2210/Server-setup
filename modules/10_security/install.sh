#!/usr/bin/env bash
## Configuration sécurité de base pour serveur, port ssh custom, fermeture port 22
## Configuration parefeu de base
## Configuration Fail2ban contre les attaque de type brute force

# Variables
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$BASE_DIR/lib/log.sh"
source "$BASE_DIR/lib/prompt.sh"

# Configuration ssh
log_info "Mise à Jour de la configuration SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak #Backup pour rollback en cas d'erreur

## desactivation du socket pour passer en mode ssh classique
systemctl disable --now ssh.socket
systemctl enable --now ssh

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

SSH_PORT=$(ask_input "Entre le nouveau port SSH" "22")

if [ -z "$SSH_PORT" ]; then
  log_error "Le port SSH ne peut pas être vide"
  exit 1
fi

if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
  log_error "Port SSH invalide : $SSH_PORT"
  exit 1
fi

# Ouverture du nouveau port sur le parefeu
ufw allow "$SSH_PORT"/tcp
log_info "Port UFW ouvert pour connexion ssh : $SSH_PORT"

# Maj du fichier de config
update_sshd_config "Port" "$SSH_PORT"
update_sshd_config "PermitRootLogin" "no"
update_sshd_config "PasswordAuthentication" "no"

# Contrôles
if ! sshd -t; then
  log_error "Configuration SSH invalide, restauration du backup"
  cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
  exit 1
fi
systemctl restart ssh

if ss -tln | grep -q ":$SSH_PORT"; then
  log_info "SSH is listening on port $SSH_PORT"
else
  log_error "SSH is NOT listening on port $SSH_PORT"
  exit 1
fi

if ! systemctl is-active --quiet ssh; then
  log_error "SSH service is not running"
  exit 1
fi

# Config du parefeu
# garder 22 temporairement ouvert
ufw allow 22/tcp

# configuration de base (80 http et 443 https)
ufw default deny incoming
ufw default allow outgoing
ufw allow 80
ufw allow 443
ufw --force enable

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

# instalation Fail2ban
apt install -y fail2ban
cp "$BASE_DIR/config/jail.local" /etc/fail2ban/jail.local
sed -i "s/^port = .*/port = $SSH_PORT/" /etc/fail2ban/jail.local

systemctl enable fail2ban
systemctl restart fail2ban

log_info "Fail2ban actif : protection SSH activée sur port $SSH_PORT"