#!/usr/bin/env bash

## ============================================================================
## QA - Contrôles statiques Server Setup
##
## Usage :
##   qa/lint.sh
##   QA_ALLOW_MISSING_TOOLS=true qa/lint.sh
##
## Le mode tolérant est utile sur un poste de développement. La CI doit laisser
## QA_ALLOW_MISSING_TOOLS à false afin qu'un linter absent bloque la validation.
## ============================================================================

set -euo pipefail

QA_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$QA_DIR/.." && pwd)"
ALLOW_MISSING_TOOLS="${QA_ALLOW_MISSING_TOOLS:-false}"
FAILED=false
ERRORS=()
ERROR_DETAILS=()

if ! command -v rg >/dev/null 2>&1; then
    printf '[QA][ERROR] Outil requis absent : ripgrep (rg)\n' >&2
    exit 1
fi

log_ok() { printf '[QA][OK] %s\n' "$1"; }
log_warn() { printf '[QA][WARN] %s\n' "$1" >&2; }
log_error() {
    ERRORS+=("$1")
    FAILED=true
}

log_error_detail() {
    ERROR_DETAILS+=("$1"$'\n'"$2")
}

require_tool() {
    local tool="$1"

    if command -v "$tool" >/dev/null 2>&1; then
        return 0
    fi

    if [ "$ALLOW_MISSING_TOOLS" = true ]; then
        log_warn "Outil absent, contrôle ignoré : $tool"
        return 1
    fi

    log_error "Outil requis absent : $tool"
    return 1
}

run_bash_syntax() {
    local file
    local count=0

    while IFS= read -r file; do
        if bash -n "$file"; then
            count=$((count + 1))
        else
            log_error "Syntaxe Bash invalide : ${file#"$PROJECT_DIR/"}"
        fi
    done < <(rg --files "$PROJECT_DIR" -g '*.sh' -g 'bin/setup' | sort)

    if [ "$FAILED" = false ]; then
        log_ok "Syntaxe Bash ($count fichiers)"
    fi
}

run_shellcheck() {
    local output
    require_tool shellcheck || return 0

    mapfile -t files < <(rg --files "$PROJECT_DIR" -g '*.sh' -g 'bin/setup' | sort)
    if output=$(shellcheck "${files[@]}" 2>&1); then
        log_ok "ShellCheck"
    else
        log_error "ShellCheck"
        log_error_detail "ShellCheck" "$output"
    fi
}

run_shfmt() {
    local output
    require_tool shfmt || return 0

    mapfile -t files < <(rg --files "$PROJECT_DIR" -g '*.sh' -g 'bin/setup' | sort)
    if output=$(shfmt -d -i 4 -ci "${files[@]}" 2>&1); then
        log_ok "shfmt"
    else
        log_error "shfmt : formatage requis"
        log_error_detail "shfmt" "$output"
    fi
}

run_markdownlint() {
    local tool=""
    local output

    if command -v markdownlint >/dev/null 2>&1; then
        tool="markdownlint"
    elif command -v markdownlint-cli >/dev/null 2>&1; then
        tool="markdownlint-cli"
    else
        require_tool markdownlint || return 0
    fi

    mapfile -t files < <(rg --files "$PROJECT_DIR" -g '*.md' | sort)
    if output=$("$tool" "${files[@]}" 2>&1); then
        log_ok "Markdownlint"
    else
        log_error "Markdownlint"
        log_error_detail "Markdownlint" "$output"
    fi
}

run_tomllint() {
    local output

    rg --files "$PROJECT_DIR" -g '*.toml*' >/dev/null 2>&1 || return 0
    require_tool taplo || return 0

    mapfile -t files < <(rg --files "$PROJECT_DIR" -g '*.toml*' | sort)
    if output=$(taplo fmt --check "${files[@]}" 2>&1); then
        log_ok "Taplo"
    else
        log_error "Taplo : formatage requis"
        log_error_detail "Taplo" "$output"
    fi
}

run_yaml_lint() {
    local output
    rg --hidden --files "$PROJECT_DIR" -g '!.git/**' -g '*.yml' -g '*.yaml' >/dev/null 2>&1 || return 0
    require_tool yamllint || return 0

    mapfile -t files < <(rg --hidden --files "$PROJECT_DIR" -g '!.git/**' -g '*.yml' -g '*.yaml' | sort)
    if output=$(yamllint "${files[@]}" 2>&1); then
        log_ok "Yamllint"
    else
        log_error "Yamllint"
        log_error_detail "Yamllint" "$output"
    fi
}

run_caddy_validate() {
    local output
    require_tool caddy || return 0

    if output=$(caddy validate --config "$PROJECT_DIR/config/Caddyfile.example" --adapter caddyfile 2>&1); then
        log_ok "Validation Caddy"
    else
        log_error "Validation Caddy"
        log_error_detail "Validation Caddy" "$output"
    fi
}

run_setup_help_check() {
    local help command
    local commands=(
        all install system security security-deluser docker reverse-proxy proxy
        backup restore logrotate logs updates update reboot monitoring healthcheck
        finalize check
    )

    help="$(bash "$PROJECT_DIR/bin/setup" --help)"

    for command in "${commands[@]}"; do
        if grep -Eq "(^|[[:space:],])${command}(,|[[:space:]])" <<<"$help"; then
            continue
        fi

        log_error "Commande absente de setup --help : $command"
    done

    if [ "$FAILED" = false ]; then
        log_ok "Inventaire setup --help"
    fi
}

run_script_permissions_check() {
    local file

    while IFS= read -r file; do
        if [ -x "$file" ]; then
            continue
        fi

        log_error "Script non exécutable : ${file#"$PROJECT_DIR/"}"
    done < <(rg --files "$PROJECT_DIR" -g '*.sh' -g 'bin/setup' | sort)

    if [ "$FAILED" = false ]; then
        log_ok "Permissions des scripts"
    fi
}

run_module_header_check() {
    local file

    while IFS= read -r file; do
        if sed -n '1,14p' "$file" | grep -q '^## Module '; then
            continue
        fi

        log_error "Bloc descriptif absent : ${file#"$PROJECT_DIR/"}"
    done < <(find "$PROJECT_DIR/modules" -mindepth 2 -maxdepth 2 -name install.sh -print | sort)

    if [ "$FAILED" = false ]; then
        log_ok "En-têtes des modules"
    fi
}

run_bash_syntax
run_shellcheck
run_shfmt
run_markdownlint
run_tomllint
run_yaml_lint
run_caddy_validate
run_setup_help_check
run_script_permissions_check
run_module_header_check

if $FAILED; then
    printf '\n[QA][SUMMARY] Échecs détectés :\n' >&2
    for error in "${ERRORS[@]}"; do
        printf '[QA][ERROR] %s\n' "$error" >&2
    done

    for detail in "${ERROR_DETAILS[@]}"; do
        detail_name="${detail%%$'\n'*}"
        detail_output="${detail#*$'\n'}"
        printf '\n[QA][DETAIL] %s\n%s\n' "$detail_name" "$detail_output" >&2
    done

    exit 1
fi

log_ok "QA terminée."
