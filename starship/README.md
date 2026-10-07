# Starship on macOS

Starship provides the zsh prompt. This config keeps every directory segment visible (`truncation_length = 0`) and does not shorten the path at Git repository boundaries (`truncate_to_repo = false`). Home is shown as `~` so the prompt works for the account on each Mac. All other prompt modules, symbols, and colors use Starship’s defaults. Baseline: **Starship 1.26.0**; Homebrew installs its current version.

## Install on another Mac

Install Apple’s Command Line Tools if needed (`xcode-select --install`) and finish the installer. Install [Homebrew](https://brew.sh) if needed and follow its printed PATH instructions for your Mac’s architecture.

Install Starship and the font used by this setup:

```sh
brew install starship
brew install --cask font-jetbrains-mono-nerd-font
```

Select **JetBrainsMono Nerd Font Mono** in your terminal. [Kitty’s guide](../kitty/README.md) reproduces the matching font, colors, and transparency; those are terminal settings, separate from the prompt.

Clone once into a permanent location. Skip this command if you already cloned for another app in this repo. Use your normal GitHub authentication if the repository is private.

```sh
git clone https://github.com/TomasTillmann/dot-files.git "$HOME/.dot-files"
```

Back up any existing config file or symlink, then link **the TOML file**, not the folder:

```sh
mkdir -p "$HOME/.config"
if [ -e "$HOME/.config/starship.toml" ] || [ -L "$HOME/.config/starship.toml" ]; then
  mv "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.backup-$(date +%Y%m%d-%H%M%S)"
fi
ln -s "$HOME/.dot-files/starship/starship.toml" "$HOME/.config/starship.toml"
```

Add these lines to `~/.zshrc` once, after any other prompt/theme setup. Replace an existing Starship initialization rather than adding it twice:

```zsh
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
eval "$(starship init zsh)"
```

Open a new terminal. The explicit `STARSHIP_CONFIG` ensures this file is used even if another config path was previously set. This follows [Starship’s zsh installation guide](https://starship.rs/guide/#step-2-set-up-your-shell-to-use-starship) and [configuration-file documentation](https://starship.rs/config/#config-file-location).

## Verify

```sh
starship --version
starship print-config directory
starship module directory --path "$PWD"
```

The printed config should contain `truncation_length = 0`, `truncate_to_repo = false`, and `home_symbol = "~"`. Navigate into a deeply nested directory and into a Git repo: all directory segments should remain visible. At your home directory the prompt shows `~`; under it, a path such as `~/Documents/project/src`.

`starship.toml` is the only config file required. Shell initialization is in the README because symlinking a TOML file does not enable Starship in zsh. Logs, caches, project contents, and credentials are not included.
