#!/usr/bin/env bash

## ============================================================================
## Module 80_monitoring
## Installation d'Ember et Vector pour le monitoring serveur
##
## - Ember surveille Caddy via son API locale et ses métriques.
## - Vector collecte les journaux système, Docker et Symfony au format JSON.
## - L'endpoint central reste configurable tant que son contrat n'est pas finalisé.
## ============================================================================

set -euo pipefail

MODULE_DIR="$PROJECT_DIR/modules/80_monitoring"

log_module "Installation du monitoring serveur"

source "$MODULE_DIR/steps/10_environment.sh"
source "$MODULE_DIR/steps/20_ember.sh"
source "$MODULE_DIR/steps/30_vector.sh"
source "$MODULE_DIR/steps/40_summary.sh"

log_success "Monitoring serveur installé."
