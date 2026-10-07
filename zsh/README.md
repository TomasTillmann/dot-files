# zsh on macOS

`zshrc` holds the shared shell settings: Neovim as `vim`/`vi`/`EDITOR`/`VISUAL`, the Yazi `f` wrapper, the Starship prompt, Ctrl+R history search, and the Neovim popup-terminal hook. It contains the zsh lines from the [Neovim](../neovim/README.md), [Yazi](../yazi/README.md), and [Starship](../starship/README.md) guides, so source it instead of adding those lines one by one.

`~/.zshrc` itself stays a normal, untracked file: installers (Homebrew, uv, Rancher Desktop, …) append PATH changes to it, and it is where machine-specific settings and credentials belong. Add this line at its end, after PATH setup, replacing any of the individual lines above that are already there:

```zsh
source "$HOME/.dot-files/zsh/zshrc"
```

Install Neovim, Yazi, and Starship with their guides first; this file expects `~/.config/yazi/f.zsh`, `starship`, and `~/.config/nvim/shell/popup.zsh` to exist. Open a new terminal and check with `type f`, `alias vim`, and `bindkey '^R'`.
