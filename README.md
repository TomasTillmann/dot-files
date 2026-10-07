# Mac dot files

Portable Kitty, Neovim, Yazi, and Starship configuration for macOS. Clone this repository to `~/.dot-files`; each app's config path is a symlink into it:

| Config path | Links to |
| --- | --- |
| `~/.config/kitty` | `~/.dot-files/kitty` |
| `~/.config/nvim` | `~/.dot-files/neovim` |
| `~/.config/yazi` | `~/.dot-files/yazi` |
| `~/.config/starship.toml` | `~/.dot-files/starship/starship.toml` |

Editing a config edits this repository, so syncing is `git commit` and `git push` here, and `git pull` on another Mac. Machine-specific files (Kitty `local.conf` and `sessions/`) are ignored by Git. `~/.zshrc` is not tracked because it holds local credentials; each guide lists the lines to add to it.

Start with the installation guide for each app:

- [Kitty setup, appearance, shortcuts, and local sessions](kitty/README.md)
- [Neovim setup, locked plugins/tools, shell integration, and shortcuts](neovim/README.md)
- [Yazi file manager, `f` shell function, and clipboard shortcut](yazi/README.md)
- [Starship prompt and zsh initialization](starship/README.md)

```text
.dot-files/
├── README.md
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
└── starship/
    ├── README.md
    └── starship.toml
```

The folder named `neovim` installs as `~/.config/nvim`. Each guide is self-contained; all use the same clone at `~/dot-files`. Personal workspace sessions, project directories, credentials, plugin downloads, and caches are not part of the shared setup.
