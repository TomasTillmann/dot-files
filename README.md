# Mac dot files

Portable Kitty, Neovim, Yazi, and Starship configuration for macOS. Clone this repository to `~/.dot-files`; each app's config path is a symlink into it:

| Config path | Links to |
| --- | --- |
| `~/.config/kitty` | `~/.dot-files/kitty` |
| `~/.config/nvim` | `~/.dot-files/neovim` |
| `~/.config/yazi` | `~/.dot-files/yazi` |
| `~/.config/starship.toml` | `~/.dot-files/starship/starship.toml` |
| `~/.zshrc` (local file) | sources `~/.dot-files/zsh/zshrc` |

Editing a config edits this repository, so syncing is `git commit` and `git push` here, and `git pull` on another Mac. Machine-specific files (Kitty `local.conf` and `sessions/`) are ignored by Git. `~/.zshrc` stays local because installers write to it and it may hold credentials; it sources the shared [zsh settings](zsh/README.md).

On a new Mac, install [Homebrew](https://brew.sh), clone the repository, and install the apps and tools these configs use from the [Brewfile](Brewfile): Kitty, the Nerd Font, Neovim and its tools, Codex and Claude Code, Yazi, Starship, VS Code, and Chrome. It is a hand-picked list, not a dump of everything installed:

```sh
git clone https://github.com/TomasTillmann/dot-files.git "$HOME/.dot-files"
brew bundle --file "$HOME/.dot-files/Brewfile"
```

`brew bundle check --file "$HOME/.dot-files/Brewfile"` lists entries that are missing or outdated. Apps installed outside Homebrew (for example Chrome downloaded from its website) are reported as missing; `brew install --cask --adopt <name>` lets Homebrew manage the existing copy.

Then link each config following its guide:

- [Kitty setup, appearance, shortcuts, and local sessions](kitty/README.md)
- [Neovim setup, locked plugins/tools, shell integration, and shortcuts](neovim/README.md)
- [Yazi file manager, `f` shell function, and clipboard shortcut](yazi/README.md)
- [Starship prompt and zsh initialization](starship/README.md)
- [Shared zsh settings](zsh/README.md)

```text
.dot-files/
├── README.md
├── Brewfile
├── .gitignore
├── kitty/
│   ├── README.md
│   ├── .gitignore
│   ├── kitty.conf
│   └── theme.conf
├── neovim/
│   ├── README.md
│   ├── AGENTS.md
│   ├── .gitignore
│   ├── .stylua.toml
│   ├── init.lua
│   ├── lazy-lock.json
│   ├── lua/
│   ├── shell/popup.zsh
│   └── tests/
├── yazi/
│   ├── README.md
│   ├── keymap.toml
│   └── f.zsh
├── starship/
│   ├── README.md
│   └── starship.toml
└── zsh/
    ├── README.md
    └── zshrc
```

The folder named `neovim` installs as `~/.config/nvim`. Each guide is self-contained; all use the same clone at `~/dot-files`. Personal workspace sessions, project directories, credentials, plugin downloads, and caches are not part of the shared setup.
