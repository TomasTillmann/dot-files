# Dot files

Kitty and Neovim configuration from my Mac, including the current Neovim plugin lockfile, shell hook, documentation, and checks.

## Install on another machine

Install Kitty, Neovim, and JetBrainsMono Nerd Font Mono. Neovim’s external tools and explicit plugin/tool installation steps are documented in [neovim/README.md](neovim/README.md#dependencies-and-updates); startup does not download them automatically.

Clone this repository to a permanent location and link the two config folders:

```sh
git clone git@github.com:TomasTillmann/dot-files.git "$HOME/dot-files"
mkdir -p "$HOME/.config"
ln -s "$HOME/dot-files/kitty" "$HOME/.config/kitty"
ln -s "$HOME/dot-files/neovim" "$HOME/.config/nvim"
```

If either config path already exists, move it to a backup location first. Neovim’s config directory is named `nvim`, even though the repository folder is named `neovim`.

## Machine-specific settings

- Kitty uses macOS Cmd/Option shortcuts. Adjust those mappings for another operating system.
- Kitty automatically opens `kitty/sessions/auctions.kitty-session`. This snapshot contains `/Users/tomastillmann/Terminus/power-us-auctions-monorepo` and launches Neovim, Claude, and Codex. Before launching Kitty on another machine, edit the two project paths and launch commands, or comment out `startup_session` in `kitty/kitty.conf` to start normally.
- Install/authenticate agent CLIs separately; credentials and runtime caches are not included.
- For Neovim’s popup shell, add the hook shown in [neovim/README.md](neovim/README.md#daily-use) to `~/.zshrc`. Caps Lock → Escape is an OS setting and is not included here.

The configs retain this Mac’s behavior. The old Kitty backup and Neovim’s original Git history are excluded.
