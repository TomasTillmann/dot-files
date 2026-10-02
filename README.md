# Mac dot files

Portable Kitty, Neovim, and Yazi configuration for macOS. Start with the installation guide for each app:

- [Kitty setup, appearance, shortcuts, and local sessions](kitty/README.md)
- [Neovim setup, locked plugins/tools, shell integration, and shortcuts](neovim/README.md)
- [Yazi file manager, `f` shell function, and clipboard shortcut](yazi/README.md)

```text
dot-files/
├── README.md
├── .gitignore
├── kitty/
│   ├── README.md
│   ├── .gitignore
│   ├── kitty.conf
│   └── theme.conf
├── neovim/
│    ├── README.md
│    ├── AGENTS.md
│    ├── .gitignore
│    ├── .stylua.toml
│    ├── init.lua
│    ├── lazy-lock.json
│    ├── lua/
│    ├── shell/popup.zsh
│    └── tests/
└── yazi/
    ├── README.md
    ├── keymap.toml
    └── f.zsh
```

The folder named `neovim` installs as `~/.config/nvim`. Each guide is self-contained; all use the same clone at `~/dot-files`. Personal workspace sessions, project directories, credentials, plugin downloads, and caches are not part of the shared setup.
