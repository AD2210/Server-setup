#!/usr/bin/env bash
## Configuration du reverse proxy multi endpoint

# Controle de droit avant execution
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Variables
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$BASE_DIR/lib/log.sh"
source "$BASE_DIR/lib/prompt.sh"
APPS_DIR="/srv/apps"
CADDYFILE="/etc/caddy/Caddyfile"

if [ ! -w "$CADDYFILE" ]; then
  log_error "Pas de permission sur $CADDYFILE"
  exit 1
fi

# Backup Caddyfile
cp "$CADDYFILE" "$CADDYFILE.bak.$(date +%s)"

# Lecture des ports déjà utilisé
get_used_ports() {
  grep -E "reverse_proxy .*:[0-9]+" "$CADDYFILE" | grep -o '[0-9]*$' | sort -n | uniq
}

# Lecture des fichiers .env
get_env_files() {
  find "$APPS_DIR" -type f -name ".env*" ! -path "*/node_modules/*" ! -path "*/.git/*"
}

get_db_ports_with_app() {
  get_env_files | while read file; do
    APP=$(dirname "$file" | xargs basename)

    grep -E "(_PORT)=([0-9]+)" "$file" 2>/dev/null \
      | grep -Ei "DB_PORT|POSTGRES_PORT|MYSQL_PORT" \
      | while read line; do
        PORT=$(echo "$line" | cut -d '=' -f2)
        echo "$APP -> $PORT"
      done
  done
}

show_ports_info() {
  log_info "Ports déjà utilisés :"
  get_used_ports | tr '\n' ' '
  echo ""

  log_info "Plages recommandées :"
  echo "  - Frontend : 3000-3999"
  echo "  - API      : 8000-8999"
  echo "  - Divers   : 9000+"
}

ask_port() {
  while true; do
    show_ports_info

    PORT=$(ask_input "Port" "")

    if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
      log_error "Port invalide"
      continue
    fi

    if get_used_ports | grep -q "^$PORT$"; then
      log_error "Port déjà utilisé"
      continue
    fi

    echo "$PORT"
    return
  done
}

# Controle de droit avant execution
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Ajout d'une nouvelle application
APP_NAME=$(ask_input "Nom de l'app" "app1")

if docker ps -a --format '{{.Names}}' | grep -q "^$SERVICE$"; then
  log_error "Service docker déjà existant"
  continue
fi

# input des endpoints, domaine et port
ENDPOINTS=()

while confirm "Ajouter un endpoint ?"; do
  DOMAIN=$(ask_input "Domaine" "example.com")
  if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    log_error "Domaine invalide"
    continue
  fi
  if grep -q "$DOMAIN" "$CADDYFILE"; then
    log_error "Domaine déjà utilisé"
    continue
  fi
  PORT=$(ask_port)
  SERVICE=$(ask_input "Service docker" "$APP_NAME")

  ENDPOINTS+=("$DOMAIN|$PORT|$SERVICE")
done

# controle d'erreur si variable vide
if [ ${#ENDPOINTS[@]} -eq 0 ]; then
  log_error "Aucun endpoint défini"
  exit 1
fi

# création de l'arborésence des runtimes
if [ ! -d "$APPS_DIR" ]; then
  log_warn "Dossier $APPS_DIR absent, création..."
  mkdir -p "$APPS_DIR"
  chown -R root:root "$APPS_DIR"
  chmod 755 "$APPS_DIR"
fi

APP_DIR="$APPS_DIR/$APP_NAME"

if [ -d "$APP_DIR" ]; then
  log_error "L'application existe déjà"
  exit 1
fi

# création du dossier de l'app, elevation des privilèges
log_info "Création du dossier $APP_DIR"
mkdir -p "$APP_DIR"
chown -R root:root "$APPS_DIR"
chmod 755 "$APPS_DIR"
cd "$APP_DIR"

# Controle des conflicts de port DB pour générer le template compose.yaml 
log_info "Ports DB détectés (indicatif, basé sur .env) :"
get_db_ports_with_app

echo ""

# Template compose.yaml
echo ""
log_info "Template docker-compose minimal :"
echo ""

cat <<EOF
services:
  app:
    image: <your-image>
    container_name: $APP_NAME
    restart: unless-stopped
    ports:
      - target : 80
        host_ip : ${APP_HTTP_IP:-127.0.0.1} # adresse interne de l'hote utilisé par caddy
        published : ${APP_HTTP_PORT:-8080}" # port HTTP interne utilisé par Caddy, par défaut 8080, à bindé dans .env
        protocole : tcp
    env_file:
      - ${APP_ENV_FILE:-.env}

  database:
    image: postgres:${POSTGRES_VERSION:-16}-alpine
    restart: unless-stopped
    volumes:
      - database_data:/var/lib/postgresql/data:rw
    ports
      - "${POSTGRES_PORT:-5432}:5432"

volumes:
  database_data:
EOF

# Template .env
echo ""
log_info "Template .env à compléter :"
echo ""

cat <<EOF
# App
APP_ENV=prod
APP_SECRET=change-me

# HTTP
APP_HTTP_PORT=$PORT
APP_HTTP_IP=127.0.0.1

# Database
POSTGRES_VERSION=16
POSTGRES_HOST=database
POSTGRES_PORT=5432
POSTGRES_NAME=$APP_NAME
POSTGRES_USER=$APP_NAME
POSTGRES_PASSWORD=change-me
EOF

echo ""
if ! confirm "Continuer avec la configuration Caddy ?"; then
  log_warn "Annulation du déploiement"
  exit 0
fi

# Controle avant d'ajouter la configuration
if grep -q "# --- $APP_NAME ---" "$CADDYFILE"; then
  log_error "Une configuration existe déjà pour $APP_NAME dans Caddy"
  exit 1
fi

log_info "Ajout de la configuration dans Caddyfile"

{
  echo ""
  echo "# --- $APP_NAME ---"

  for endpoint in "${ENDPOINTS[@]}"; do
    IFS="|" read DOMAIN PORT SERVICE <<< "$endpoint"

    cat <<EOF
$DOMAIN {
    reverse_proxy $SERVICE:$PORT
}

EOF

  done

  echo "# --- END $APP_NAME ---"
} >> "$CADDYFILE"

# Validation final
if ! caddy validate --config "$CADDYFILE"; then
  log_error "Configuration Caddy invalide"
  exit 1
fi

log_info "Reload de Caddy"
systemctl reload caddy

echo ""
log_info "Déploiement reverse proxy terminé :"

for endpoint in "${ENDPOINTS[@]}"; do
  IFS="|" read DOMAIN PORT SERVICE <<< "$endpoint"
  echo "  → http://$DOMAIN → $SERVICE:$PORT"
done