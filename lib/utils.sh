load_env() {
  if [ -f "./config/default.env" ]; then
    source "./config/default.env"
  fi
}
command_exists() { command -v "$1" >/dev/null 2>&1; }
