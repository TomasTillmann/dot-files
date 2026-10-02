# Start Yazi and switch this shell to its last directory on exit.
function f() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd

  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"

  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"

  command rm -f -- "$tmp"
}
