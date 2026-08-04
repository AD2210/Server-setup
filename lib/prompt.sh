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