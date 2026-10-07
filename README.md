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

## New Mac

Install [Homebrew](https://brew.sh), then clone and run the setup script:

```sh
git clone https://github.com/TomasTillmann/dot-files.git "$HOME/.dot-files"
"$HOME/.dot-files/install.sh"
```

`install.sh` is safe to re-run. It:

1. Installs the hand-picked [Brewfile](Brewfile) (`--no-brew` skips this): Kitty, the Nerd Font, Neovim and its tools, Codex and Claude Code, Yazi, Starship, gitleaks, VS Code, and Chrome. Apps installed outside Homebrew are reported as failures; `brew install --cask --adopt <name>` lets Homebrew manage the existing copy.
2. Creates the config links in the table above, moving anything already there to `<name>.backup-<timestamp>`.
3. Adds `source "$HOME/.dot-files/zsh/zshrc"` to `~/.zshrc` if it is missing. Remove older copies of those settings from `~/.zshrc` afterwards.
4. On a fresh Neovim install, bootstraps Lazy and installs the locked plugins, pinned Mason tools, and syntax parsers.
5. Enables the secret-scanning commit hook below.

Remaining manual steps: map Caps Lock to Escape ([Kitty guide](kitty/README.md)) and sign in to the agent CLIs ([Neovim guide](neovim/README.md)). `brew bundle check --file "$HOME/.dot-files/Brewfile"` lists missing or outdated packages later.

## Secret scanning

This repository is public. `.githooks/pre-commit` runs [gitleaks](https://github.com/gitleaks/gitleaks) on staged changes and blocks the commit if it finds a key, token, or password; `install.sh` enables it with `git config core.hooksPath .githooks`. If a finding is a false positive, adjust the change or, after checking it, commit with `git commit --no-verify`. Scan the whole history with `gitleaks git .`.

## Per-app guides

Each guide explains its config and the manual equivalent of the setup script:

- [Kitty setup, appearance, shortcuts, and local sessions](kitty/README.md)
- [Neovim setup, locked plugins/tools, shell integration, and shortcuts](neovim/README.md)
- [Yazi file manager, `f` shell function, and clipboard shortcut](yazi/README.md)
- [Starship prompt and zsh initialization](starship/README.md)
- [Shared zsh settings](zsh/README.md)

```text
.dot-files/
├── README.md
├── Brewfile
├── install.sh
├── .githooks/pre-commit
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
