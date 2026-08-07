ask() {
  read -p "$1 (y/n): " choice
  case "$choice" in y|Y ) return 0 ;; * ) return 1 ;; esac
}

ask_input() {
  local prompt="$1"
  local default="$2"
  read -p "$prompt [$default]: " value
  echo "${value:-$default}"
}

confirm() {
  local prompt="$1"
  read -p "$prompt (y/N): " choice
  case "$choice" in
    y|Y ) return 0 ;;
    * ) return 1 ;;
  esac
}

run_quiet() {
    local message="$1"
    shift

    local error_file
    error_file="$(mktemp)"

    if "$@" >/dev/null 2>"$error_file"; then
        rm -f "$error_file"
        return 0
    fi

    log_error "$message"

    if [ -s "$error_file" ]; then
        cat "$error_file" >&2
    fi

    rm -f "$error_file"
    return 1
}