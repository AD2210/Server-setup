ask() {
  read -p "$1 (y/n): " choice
  case "$choice" in y|Y ) return 0 ;; * ) return 1 ;; esac
}
