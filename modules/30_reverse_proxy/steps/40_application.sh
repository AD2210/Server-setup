#!/usr/bin/env bash

## ============================================================================
## Étape 40 - Préparation du runtime applicatif
##
## - affiche les ports DB existants
## - affiche les bindings à intégrer dans Compose
## - affiche les variables .env correspondantes
## - crée /srv/apps/<app> après confirmation
##
## Le script ne génère pas le compose applicatif.
## ============================================================================

log_step "Préparation du runtime applicatif"

show_db_ports_info

log ""
log_info "Configuration Compose à intégrer dans l'application :"
log ""

for endpoint in "${ENDPOINTS[@]}"; do
    IFS="|" read -r DOMAIN HOST_PORT SERVICE CONTAINER_PORT <<< "$endpoint"

    ENV_PREFIX="$(printf '%s' "$SERVICE" | tr '[:lower:].-' '[:upper:]__')"

    cat <<EOF
# $DOMAIN
services:
  $SERVICE:
    ports:
      - target: $CONTAINER_PORT
        host_ip: \${${ENV_PREFIX}_HTTP_IP:-127.0.0.1}
        published: "\${${ENV_PREFIX}_HTTP_PORT:-$HOST_PORT}"
        protocol: tcp

EOF
done

log "  Exemple DB PostgreSQL accessible uniquement depuis l'hôte :"
log ""
cat <<'EOF'
services:
  database:
    ports:
      - target: 5432
        host_ip: 127.0.0.1
        published: "${POSTGRES_PORT:-5432}"
        protocol: tcp
EOF

log ""
log_info "Variables .env à ajouter :"
log ""

for endpoint in "${ENDPOINTS[@]}"; do
    IFS="|" read -r DOMAIN HOST_PORT SERVICE CONTAINER_PORT <<< "$endpoint"
    ENV_PREFIX="$(printf '%s' "$SERVICE" | tr '[:lower:].-' '[:upper:]__')"

    cat <<EOF
# $DOMAIN
${ENV_PREFIX}_HTTP_IP=127.0.0.1
${ENV_PREFIX}_HTTP_PORT=$HOST_PORT

EOF
done

cat <<EOF
# Database
POSTGRES_PORT=5432
EOF

log ""
log_info "Caddy utilisera uniquement les ports publiés sur 127.0.0.1."

if ! confirm "Continuer avec la création du runtime et la configuration Caddy ?"; then
    log_warn "Configuration annulée."
    exit 0
fi

mkdir -p "$APP_DIR"

# /srv/apps reste administré par root, mais le dossier de l'application
# appartient à l'utilisateur de déploiement afin de permettre SCP/CI-CD.
chown "$DEPLOY_USER:$DEPLOY_USER" "$APP_DIR"
chmod 755 "$APP_DIR"

log_info "Dossier applicatif créé : $APP_DIR"
log_info "Propriétaire : $DEPLOY_USER"
