#!/bin/bash
# Set up these dot files on a Mac: apps, config links, zsh, Neovim plugins, and the secret-scanning commit hook.
# Safe to re-run: correct links are kept, and anything else in the way is backed up first.
# Usage: ./install.sh [--no-brew]
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
stamp="$(date +%Y%m%d-%H%M%S)"
brew=1
for arg in "$@"; do
  case "$arg" in
    --no-brew) brew=0 ;;
    *) echo "usage: $0 [--no-brew]" >&2; exit 2 ;;
  esac
done

step() { printf '\n==> %s\n' "$1"; }

# Point $2 at $1, moving any other file, directory, or link at $2 aside first.
link() {
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then
    echo "ok      $2"
    return
  fi
  if [ -e "$2" ] || [ -L "$2" ]; then
    mv "$2" "$2.backup-$stamp"
    echo "backup  $2 -> $2.backup-$stamp"
  fi
  ln -s "$1" "$2"
  echo "linked  $2 -> $1"
}

if [ "$brew" = 1 ]; then
  step 'Homebrew packages (Brewfile)'
  command -v brew >/dev/null || { echo 'Install Homebrew first: https://brew.sh' >&2; exit 1; }
  brew bundle --file "$repo/Brewfile"
fi

step 'Config links'
mkdir -p "$config"
link "$repo/kitty" "$config/kitty"
link "$repo/neovim" "$config/nvim"
link "$repo/yazi" "$config/yazi"
link "$repo/starship/starship.toml" "$config/starship.toml"
mkdir -p "$repo/kitty/sessions"

step 'zsh'
# ~/.zshrc stays a local file (installers write to it); it only sources the shared settings.
source_line="source \"${repo/#$HOME/\$HOME}/zsh/zshrc\""
if [ -f "$HOME/.zshrc" ] && grep -qF "$source_line" "$HOME/.zshrc"; then
  echo "ok      ~/.zshrc sources the shared settings"
else
  printf '\n# Shared settings (editor, Yazi, Starship, key bindings) from the dot files.\n%s\n' "$source_line" >> "$HOME/.zshrc"
  echo "added   $source_line to ~/.zshrc"
  echo "        Remove any older copies of those settings from ~/.zshrc (see zsh/README.md)."
fi

step 'Neovim plugins'
nvim_data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
if [ -d "$nvim_data/lazy/lazy.nvim" ]; then
  echo "ok      plugins already installed (repair/update: see neovim/README.md)"
else
  echo "Installing locked plugins; \"Plugin ... is not installed\" messages before the clones are expected."
  mkdir -p "$nvim_data/lazy"
  git clone --filter=blob:none --no-checkout https://github.com/folke/lazy.nvim.git "$nvim_data/lazy/lazy.nvim"
  git -C "$nvim_data/lazy/lazy.nvim" checkout \
    "$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["lazy.nvim"]["commit"])' "$repo/neovim/lazy-lock.json")"
  nvim --headless '+lua require("lazy").install({wait=true, lockfile=true})' +qa
  nvim --headless '+MasonToolsInstallSync' +qa
  nvim --headless '+lua require("nvim-treesitter").install({"python","bash","diff","lua","luadoc","markdown","markdown_inline","query","vim","vimdoc"}):wait(120000)' +qa
  printf '\nok      locked plugins, pinned tools, and parsers installed\n'
fi

step 'Secret scan before commits'
git -C "$repo" config core.hooksPath .githooks
echo "ok      commits in $repo are checked by gitleaks"

step 'Done'
echo 'Open a new terminal, and reload Kitty with Ctrl+Cmd+, (or restart it).'
echo 'Manual steps: Caps Lock -> Escape (kitty/README.md) and signing in to the agent CLIs (neovim/README.md).'
