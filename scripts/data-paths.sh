dingdong_data_root() {
  local root="${DINGDONG_HOME:-$HOME/.config/dingdong}"
  case "$root" in
    /*|[A-Za-z]:[\\/]*) printf '%s\n' "$root" ;;
    *) printf 'DINGDONG_HOME must be an absolute path.\n' >&2; return 1 ;;
  esac
}

dingdong_initialize_data() {
  local source_root="$1" data_root sound
  data_root="$(dingdong_data_root)" || return
  mkdir -p "$data_root/sounds"
  for sound in "$source_root/sounds/"*.wav; do
    [ -f "$sound" ] || continue
    cp -n "$sound" "$data_root/sounds/"
  done
  cp -n "$source_root/config.json" "$data_root/config.json"
  printf '%s\n' "$data_root"
}
