# Yazi on macOS

Yazi is the terminal file manager launched by `f`. This folder preserves the current `keymap.toml` and the `f` zsh function from this Mac. The custom shortcut is **Ctrl+C → copy file path to the clipboard**; everything else uses Yazi’s defaults. There are no custom themes or plugins. Baseline: **Yazi 26.5.6**; Homebrew installs its current version.

## Install on another Mac

Install Apple’s Command Line Tools if needed (`xcode-select --install`) and finish the installer. Install [Homebrew](https://brew.sh) if needed and follow its printed PATH instructions for your Mac’s architecture.

Install Yazi and the search/preview tools used on the original Mac, plus the terminal font:

```sh
brew install yazi ffmpeg poppler fd ripgrep
brew install --cask font-jetbrains-mono-nerd-font
```

macOS supplies `file` for type detection and `pbcopy` for the clipboard. FFmpeg enables video thumbnails; Poppler enables PDF previews; fd/ripgrep enable file/content search. Extra tools such as sevenzip, jq, fzf, zoxide, and ImageMagick are optional and are not required to reproduce this config; see [Yazi’s dependency guide](https://yazi-rs.github.io/docs/installation/) if you want those features.

Clone once into a permanent location. Skip this command if you already cloned for Kitty or Neovim. Use your normal GitHub authentication if the repository is private.

```sh
git clone https://github.com/TomasTillmann/dot-files.git "$HOME/.dot-files"
```

Close Yazi, back up an existing config directory or symlink, then link this folder:

```sh
mkdir -p "$HOME/.config"
if [ -e "$HOME/.config/yazi" ] || [ -L "$HOME/.config/yazi" ]; then
  mv "$HOME/.config/yazi" "$HOME/.config/yazi.backup-$(date +%Y%m%d-%H%M%S)"
fi
ln -s "$HOME/.dot-files/yazi" "$HOME/.config/yazi"
```

Add this line to `~/.zshrc` once, replacing any existing `f` alias/function:

```zsh
source "$HOME/.config/yazi/f.zsh"
```

Open a new terminal, or run that same `source` command in the current zsh shell. Run `f` from any directory, or `f "$HOME/Documents"` to start there. This uses the standard config path `~/.config/yazi`; no username or project path is hard-coded.

For the same terminal appearance, follow [Kitty’s guide](../kitty/README.md). For files to open in Neovim, install it using [Neovim’s guide](../neovim/README.md) and add `export EDITOR='nvim'` and `export VISUAL='nvim'` to `~/.zshrc` if not already present.

## Use and verify

| Keys | Action |
| --- | --- |
| H/J/K/L or arrow keys | Parent/down/up/enter directory |
| Enter | Open the hovered file |
| Ctrl+C | Copy file path to the macOS clipboard |
| Q (Shift+Q) | Quit without changing the shell’s directory |
| q | Quit and change the shell to Yazi’s last directory |
| F1 or `~` | Show help |

Run `yazi --version` and `type f` to verify installation. Start `f`, navigate into a folder, press `q`, and run `pwd` to confirm the shell changed directory. Start it again, copy a file path with Ctrl+C, and paste it into the shell. Directly running `yazi` does not change the parent shell’s directory; the `f` wrapper supplies that behavior, following [Yazi’s shell integration](https://yazi-rs.github.io/docs/quick-start/#shell-wrapper).

Files: `keymap.toml` contains the shortcut; `f.zsh` contains shell integration. Local caches, history, project contents, and credentials are not included.
