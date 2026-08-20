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

log_ok() { printf '[QA][OK] %s\n' "$1"; }
log_warn() { printf '[QA][WARN] %s\n' "$1" >&2; }
log_error() { printf '[QA][ERROR] %s\n' "$1" >&2; FAILED=true; }

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

    while IFS= read -r file; do
        if bash -n "$file"; then
            log_ok "Syntaxe Bash : ${file#"$PROJECT_DIR/"}"
        else
            log_error "Syntaxe Bash invalide : ${file#"$PROJECT_DIR/"}"
        fi
    done < <(rg --files "$PROJECT_DIR" -g '*.sh' -g 'bin/setup' | sort)
}

run_shellcheck() {
    local file
    require_tool shellcheck || return 0

    mapfile -t files < <(rg --files "$PROJECT_DIR" -g '*.sh' -g 'bin/setup' | sort)
    if shellcheck "${files[@]}"; then
        log_ok "ShellCheck"
    else
        log_error "ShellCheck"
    fi
}

run_shfmt() {
    require_tool shfmt || return 0

    if shfmt -d -i 4 -ci \
        $(rg --files "$PROJECT_DIR" -g '*.sh' -g 'bin/setup' | sort); then
        log_ok "shfmt"
    else
        log_error "shfmt : formatage requis"
    fi
}

run_markdownlint() {
    local tool=""
    local file

    if command -v markdownlint >/dev/null 2>&1; then
        tool="markdownlint"
    elif command -v markdownlint-cli >/dev/null 2>&1; then
        tool="markdownlint-cli"
    else
        require_tool markdownlint || return 0
    fi

    if "$tool" $(rg --files "$PROJECT_DIR" -g '*.md' | sort); then
        log_ok "Markdownlint"
    else
        log_error "Markdownlint"
    fi
}

run_tomllint() {
    local file

    rg --files "$PROJECT_DIR" -g '*.toml*' >/dev/null 2>&1 || return 0
    require_tool taplo || return 0

    if taplo fmt --check $(rg --files "$PROJECT_DIR" -g '*.toml*' | sort); then
        log_ok "Taplo"
    else
        log_error "Taplo : formatage requis"
    fi
}

run_yaml_lint() {
    rg --hidden --files "$PROJECT_DIR" -g '!.git/**' -g '*.yml' -g '*.yaml' >/dev/null 2>&1 || return 0
    require_tool yamllint || return 0

    if yamllint $(rg --hidden --files "$PROJECT_DIR" -g '!.git/**' -g '*.yml' -g '*.yaml' | sort); then
        log_ok "Yamllint"
    else
        log_error "Yamllint"
    fi
}

run_caddy_validate() {
    require_tool caddy || return 0

    if caddy validate --config "$PROJECT_DIR/config/Caddyfile.example" --adapter caddyfile; then
        log_ok "Validation Caddy"
    else
        log_error "Validation Caddy"
    fi
}

run_bash_syntax
run_shellcheck
run_shfmt
run_markdownlint
run_tomllint
run_yaml_lint
run_caddy_validate

if $FAILED; then
    exit 1
fi

log_ok "QA terminée."
