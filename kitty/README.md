# Kitty on macOS

This config reproduces the terminal appearance and keyboard behavior on another Mac: JetBrainsMono Nerd Font Mono at 14 pt with ligatures, Rosé Pine colors, 90% background opacity, dimmed inactive panes, and stack/split layouts. Baseline: Kitty **0.47.4** and Nerd Fonts **3.4.0**. Use Kitty 0.47.4 or newer for these session commands. Homebrew installs its current package versions.

## Install

1. Install Apple’s Command Line Tools if needed (`xcode-select --install`) and finish the installer. Install [Homebrew](https://brew.sh) if needed, then follow its printed shell/PATH instructions; these differ between Apple Silicon and Intel Macs.
2. Install [Kitty](https://formulae.brew.sh/cask/kitty) and the [font](https://formulae.brew.sh/cask/font-jetbrains-mono-nerd-font):

```sh
brew install --cask kitty font-jetbrains-mono-nerd-font
```

3. Clone once into a permanent location. If you already cloned this repo while installing Neovim, skip this command. Use your normal GitHub authentication if the repository is private.

```sh
git clone https://github.com/TomasTillmann/dot-files.git "$HOME/.dot-files"
```

4. Quit Kitty before changing its config. Use the standard macOS config path `~/.config/kitty`. Back up an existing directory or symlink, then link the config and create the local sessions directory:

```sh
mkdir -p "$HOME/.config"
if [ -e "$HOME/.config/kitty" ] || [ -L "$HOME/.config/kitty" ]; then
  mv "$HOME/.config/kitty" "$HOME/.config/kitty.backup-$(date +%Y%m%d-%H%M%S)"
fi
ln -s "$HOME/.dot-files/kitty" "$HOME/.config/kitty"
mkdir -p "$HOME/.config/kitty/sessions"
open -a kitty
```

Kitty uses the Mac’s default shell (normally zsh); no separate shell theme or prompt is required by this config. For the editor and agent commands, install Neovim using [its guide](../neovim/README.md).

## Shortcuts

`Option` corresponds to `opt` in `kitty.conf`; `Cmd` corresponds to `cmd`.

| Keys | Action |
| --- | --- |
| Option+Enter | New tab |
| Option+T | Close tab |
| Option+Tab | Next tab |
| Option+1–9 | Select tab by position |
| Cmd+W / Option+W | Close current pane/window |
| Option+M | Toggle stack layout |
| Cmd+Shift+1 | Stack layout |
| Cmd+Shift+2 | Split layout |
| Option+D | Add pane beside current pane, in its directory |
| Option+Shift+D | Add pane below current pane, in its directory |
| Option+H/J/K/L | Focus pane left/down/up/right |
| Option+Shift+H/J/K/L | Move current pane left/down/up/right |
| Option+R, then H/J/K/L | Resize narrower/shorter/taller/wider; Escape exits |
| Cmd+Shift+S | Save current OS window as a local session |
| Cmd+Shift+O | Choose/open a local session |
| Ctrl+Cmd+, | Reload configuration |

Other built-in tab navigation shortcuts listed in `kitty.conf` are disabled. Built-in shortcuts not overridden there remain available.

## Local sessions

Kitty starts with a normal shell. No project or agent is opened automatically.

Arrange your own tabs/panes and press Cmd+Shift+S. Enter a short name such as `workspace`; Kitty adds `.kitty-session` and saves under `~/.config/kitty/sessions`. Reusing a name replaces the saved session. Cmd+Shift+O chooses a saved session. These files are ignored by Git because they contain local working directories and launch commands.

[Sessions](https://sw.kovidgoyal.net/kitty/sessions/) recreate layouts and relaunch saved foreground programs; they do not preserve live processes. To opt into automatic startup on one Mac, add `startup_session ~/.config/kitty/sessions/workspace.kitty-session` to `~/.config/kitty/local.conf` after saving that session. `kitty.conf` includes `local.conf` last; the file is ignored by Git, and Kitty skips it when it does not exist.

## Check the result

Restart Kitty after installing the font. Confirm the Rosé Pine colors, transparency, 14 pt font, ligatures, and Nerd Font icons. Test a new tab, a split, focus/move/resize shortcuts, and save/open a session created on this Mac. Ctrl+Cmd+, reloads later edits. If icons or the font look wrong, open Kitty’s configuration/debug information with Cmd+Option+, and check the resolved font and configuration errors.

For the same Caps Lock behavior used with Neovim, use [System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys](https://support.apple.com/guide/mac-help/change-the-behavior-of-the-modifier-keys-mchlp1011/mac), select your keyboard, and map Caps Lock to Escape. This is a macOS setting, not stored in these files.
