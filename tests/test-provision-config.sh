#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/lib/log.sh"
source "$PROJECT_DIR/lib/config.sh"
source "$PROJECT_DIR/lib/prompt.sh"
NON_INTERACTIVE=true

FEATURE=false
if confirm test FEATURE; then exit 1; else test "$?" -eq 1; fi
FEATURE=true
confirm test FEATURE
# Read indirectly by confirm through the supplied configuration key.
# shellcheck disable=SC2034
FEATURE=invalid
if confirm test FEATURE; then exit 1; else test "$?" -eq 2; fi
# shellcheck disable=SC2034
SSH_PORT=55122
test "$(ask_input port 22 SSH_PORT)" = 55122

# Explicit Docker user wins over the root session's SUDO_USER.
DOCKER_ADMIN_USER=deployment-user
ADMIN_USER=wrong-user
SUDO_USER=root
id() { test "$1" = deployment-user; }
source "$PROJECT_DIR/modules/20_docker/steps/10_user.sh"
test "$ADMIN_USER" = deployment-user
unset -f id

# Cloud-init settings are read via Include: the managed value must be first.
SSHD_CONFIG="$(mktemp)"
trap 'rm -f "$SSHD_CONFIG"' EXIT
printf 'Include /etc/ssh/sshd_config.d/*.conf\nPasswordAuthentication yes\nMatch User special\n    PasswordAuthentication yes\n' >"$SSHD_CONFIG"
eval "$(sed -n '/^update_sshd_config()/,/^}/p' "$PROJECT_DIR/modules/10_security/steps/20_ssh.sh")"
update_sshd_config PasswordAuthentication no
test "$(head -n1 "$SSHD_CONFIG")" = 'PasswordAuthentication no'
test "$(awk '$1=="PasswordAuthentication"{n++} END{print n}' "$SSHD_CONFIG")" = 2
printf 'OK: configuration booleans, SSH port, Docker user and cloud-init precedence\n'
