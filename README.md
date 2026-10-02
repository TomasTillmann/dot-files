# Mac dot files

Portable Kitty and Neovim configuration for macOS. Start with the installation guide for each app:

- [Kitty setup, appearance, shortcuts, and local sessions](kitty/README.md)
- [Neovim setup, locked plugins/tools, shell integration, and shortcuts](neovim/README.md)

```text
dot-files/
├── README.md
├── .gitignore
├── kitty/
│   ├── README.md
│   ├── .gitignore
│   ├── kitty.conf
│   └── theme.conf
└── neovim/
    ├── README.md
    ├── AGENTS.md
    ├── .gitignore
    ├── .stylua.toml
    ├── init.lua
    ├── lazy-lock.json
    ├── lua/
    ├── shell/popup.zsh
    └── tests/
```

The folder named `neovim` installs as `~/.config/nvim`. Each guide is self-contained; both use the same clone at `~/dot-files`. Personal workspace sessions, project directories, credentials, plugin downloads, and caches are not part of the shared setup.
