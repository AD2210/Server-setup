#!/usr/bin/env bash

## ============================================================================
## Module 00_system
## Mise à jour et préparation du système
##
## Ce module :
## - met à jour les dépôts APT
## - applique les mises à jour système
## - installe les dépendances de base
## - nettoie les paquets devenus inutiles
## - vérifie les composants installés
##
## Prérequis globaux :
## - privilèges root
## - Ubuntu Server LTS
## - arborescence du projet
##
## Ces prérequis sont contrôlés par bin/setup.
## ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration du module
# ----------------------------------------------------------------------------

REQUIRED_PACKAGES=(
    curl
    git
    ufw
    caddy
)

# ----------------------------------------------------------------------------
# Initialisation
# ----------------------------------------------------------------------------

log_module "Mise à jour et préparation du système"

# ----------------------------------------------------------------------------
# Mise à jour des dépôts
# ----------------------------------------------------------------------------

log_step "Mise à jour des dépôts APT"

run_quiet \
    "Impossible de mettre à jour les dépôts APT." \
    apt-get update ||
    exit 1

# ----------------------------------------------------------------------------
# Mise à jour du système
# ----------------------------------------------------------------------------

log_step "Installation des mises à jour système"

run_quiet \
    "Impossible d'appliquer les mises à jour système." \
    apt-get upgrade -y ||
    exit 1

# ----------------------------------------------------------------------------
# Installation des dépendances
# ----------------------------------------------------------------------------

log_step "Installation des dépendances système"

run_quiet \
    "Impossible d'installer les dépendances système." \
    apt-get install -y "${REQUIRED_PACKAGES[@]}" ||
    exit 1

# ----------------------------------------------------------------------------
# Nettoyage APT
# ----------------------------------------------------------------------------

log_step "Nettoyage du système"

run_quiet \
    "Impossible de supprimer les paquets devenus inutiles." \
    apt-get autoremove -y ||
    exit 1

run_quiet \
    "Impossible de nettoyer le cache APT." \
    apt-get autoclean ||
    exit 1

# ----------------------------------------------------------------------------
# Vérifications finales
# ----------------------------------------------------------------------------

log_step "Vérification de l'installation"

INSTALLATION_OK=true

for package in "${REQUIRED_PACKAGES[@]}"; do
    if command_exists "$package"; then
        log "  ${package} ..................... OK"
    else
        log_error "$package ..................... ERREUR"
        INSTALLATION_OK=false
    fi
done

if [ "$INSTALLATION_OK" != true ]; then
    log_error "La préparation du système n'est pas complètement fonctionnelle."
    log_info "Consultez les erreurs ci-dessus avant de poursuivre."
    exit 1
fi

# ----------------------------------------------------------------------------
# Fin du module
# ----------------------------------------------------------------------------

log_success "Le système est à jour et les dépendances de base sont installées."
