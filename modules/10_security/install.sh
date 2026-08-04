#!/usr/bin/env bash
## Configuration sécurité de base pour serveur, port ssh custom, fermeture port 22
## Configuration parefeu de base
## Configuration Fail2ban contre les attaque de type brute force

# Variables
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$BASE_DIR/lib/log.sh"
source "$BASE_DIR/lib/prompt.sh"

# Controle de droit avant execution
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en root (sudo)"
  exit 1
fi

# Configuration ssh
log_info "Mise à Jour de la configuration SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak #Backup pour rollback en cas d'erreur

## desactivation du socket pour passer en mode ssh classique
systemctl disable --now ssh.socket
systemctl enable --now ssh

# Lecture de config
CURRENT_SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
if [ -z "$CURRENT_SSH_PORT" ]; then
  CURRENT_SSH_PORT=22
fi

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

# Entrée + controle de saisie
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

if ! ss -tln | grep -q ":$SSH_PORT"; then
  log_error "SSH n'écoute pas sur le nouveau port, abandon"
  exit 1
fi

if ! systemctl is-active --quiet ssh; then
  log_error "Le service SSH n'est pas actif"
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
if [ "$CURRENT_SSH_PORT" != "$SSH_PORT" ]; then
  log_warn "--------------------------------------------------"
  log_warn "IMPORTANT: Port SSH modifié"
  log_warn "Avant de fermer le port $CURRENT_SSH_PORT"
  log_warn "1. Ouvrir un nouveau terminal"
  log_warn "2. Tester la connexion avec le nouveau port : ssh -p [port] [user]@[ip]"
  log_warn "3. Vérifier que la connexion reussi"
  log_warn "--------------------------------------------------"	

  if confirm "Fermer l'ancien port SSH ($CURRENT_SSH_PORT) ?"; then
    ufw delete allow "$CURRENT_SSH_PORT"/tcp
    log_info "Ancien port $CURRENT_SSH_PORT fermé"
  else
    log_info "Ancien port conservé"
  fi
fi

# instalation Fail2ban
apt install -y fail2ban
cp "$BASE_DIR/config/jail.local" /etc/fail2ban/jail.local
sed -i "s/^port = .*/port = $SSH_PORT/" /etc/fail2ban/jail.local

systemctl enable fail2ban
systemctl restart fail2ban

log_info "Fail2ban actif : protection SSH activée sur port $SSH_PORT"