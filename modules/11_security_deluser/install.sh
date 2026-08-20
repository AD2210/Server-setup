#!/usr/bin/env bash

## ============================================================================
## Module 11_security_deluser
## Suppression de l'utilisateur initial du fournisseur
##
## Ce module doit être exécuté depuis une session ouverte avec
## le nouvel utilisateur administrateur.
## ============================================================================

set -euo pipefail

log_module "Suppression de l'utilisateur initial"


# ----------------------------------------------------------------------------
# Détection de l'utilisateur courant
# ----------------------------------------------------------------------------

log_step "Vérification de la session administrateur"

CURRENT_USER="${SUDO_USER:-root}"

if [ "$CURRENT_USER" = "root" ]; then
    log_error "Impossible d'identifier un utilisateur administrateur non-root."
    log_info "Connectez-vous avec le nouvel utilisateur administrateur puis relancez."
    exit 1
fi

log_info "Session administrateur détectée : $CURRENT_USER"


# ----------------------------------------------------------------------------
# Saisie de l'utilisateur à supprimer
# ----------------------------------------------------------------------------

TARGET_USER=$(ask_input "Utilisateur initial à supprimer" "ubuntu" "INITIAL_USER")

if [ -z "$TARGET_USER" ]; then
    log_error "Aucun utilisateur renseigné."
    exit 1
fi

if [ "$TARGET_USER" = "root" ]; then
    log_error "Le compte root ne peut pas être supprimé."
    exit 1
fi

if [ "$TARGET_USER" = "$CURRENT_USER" ]; then
    log_error "Vous ne pouvez pas supprimer l'utilisateur de la session courante."
    exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    log_info "L'utilisateur '$TARGET_USER' n'existe pas."
    exit 0
fi


# ----------------------------------------------------------------------------
# Vérification des processus actifs
# ----------------------------------------------------------------------------

log_step "Recherche de processus actifs pour '$TARGET_USER'"

USER_PROCESSES="$(pgrep -u "$TARGET_USER" || true)"

if [ -n "$USER_PROCESSES" ]; then
    log_warn "Des processus sont encore exécutés par '$TARGET_USER'."
    log_info "PID détectés : $(echo "$USER_PROCESSES" | tr '\n' ' ')"
    log_info "Fermez ses sessions avant de poursuivre."
    exit 1
fi


# ----------------------------------------------------------------------------
# Confirmation
# ----------------------------------------------------------------------------

log_warn "Cette opération supprimera le compte et son dossier personnel."

if ! confirm "Supprimer définitivement '$TARGET_USER' ?" "DELETE_INITIAL_USER"; then
    log_info "Suppression annulée."
    exit 0
fi


# ----------------------------------------------------------------------------
# Suppression
# ----------------------------------------------------------------------------

log_step "Suppression de l'utilisateur '$TARGET_USER'"

if ! userdel -r "$TARGET_USER"; then
    log_error "Impossible de supprimer l'utilisateur '$TARGET_USER'."
    exit 1
fi


# ----------------------------------------------------------------------------
# Vérification finale
# ----------------------------------------------------------------------------

if id "$TARGET_USER" >/dev/null 2>&1; then
    log_error "L'utilisateur '$TARGET_USER' existe encore après suppression."
    exit 1
fi

log_success "Utilisateur '$TARGET_USER' supprimé avec succès."
