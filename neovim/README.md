# Neovim on macOS

Personal Python setup adapted from [Joel Hooks' Kickstart configuration](https://github.com/joelhooks/dotfiles/tree/c3f55039c22e9b36b93c5ba193a5ff406467e001/nvim), with its original plugin pins retained where applicable. Upstream identifies the dotfiles as MIT-licensed; the configuration derives from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim).

Symlink this repository’s `neovim` folder to `~/.config/nvim`. Editor/plugin settings are in `init.lua`; the four search actions are in `lua/search.lua`. `lazy-lock.json` records the installed plugin commits. Sidekick provides agent CLI sessions; AI completion and Next Edit Suggestions are disabled. Ordinary language-server completion remains available. Errors use underlines and gutter markers without inline text; details appear in diagnostic floats and the error list. Only error diagnostics are shown, including in the file tree, status line, diagnostic jumps, and error list. Warning/info/hint diagnostics are hidden without changing project rules. Notifications show errors only; LSP progress remains available. `:Fidget history` shows retained error notifications.

## Install on another Mac

The guide assumes the standard config path `~/.config/nvim` and macOS’s zsh shell. Use [Kitty’s guide](../kitty/README.md) for the matching terminal appearance. This Neovim setup has been tested with **Neovim 0.12.4**; the plugin and tool pins below are preserved. Homebrew installs its current application/runtime versions, so it does not freeze the complete OS or runtime environment.

### 1. Install prerequisites

Install Apple’s Command Line Tools if needed (`xcode-select --install`), finish the installer, and install [Homebrew](https://brew.sh) if needed. Follow Homebrew’s printed shell/PATH instructions for your Mac’s architecture before continuing.

```sh
brew install neovim git ripgrep fd tmux node python uv
brew install --cask font-jetbrains-mono-nerd-font
nvim --version
```

Git supplies history/diffs; ripgrep and fd supply search; Command Line Tools supply clang/make for native plugin/parser builds; Node runs fallback Pyright; Python is used for bootstrapping and projects; uv runs the integration checks. macOS supplies zsh, curl, tar, unzip, and clipboard tools. Use JetBrainsMono Nerd Font Mono in your terminal so icons align; Kitty’s config selects it automatically.

### 2. Clone and link the config

Clone once into a permanent location. Skip the clone if you already did it for Kitty. Use your normal GitHub authentication if the repository is private.

```sh
git clone https://github.com/TomasTillmann/dot-files.git "$HOME/dot-files"
```

Close Neovim, back up any existing config directory or symlink, and link the **neovim subfolder**, not the repository root:

```sh
mkdir -p "$HOME/.config"
if [ -e "$HOME/.config/nvim" ] || [ -L "$HOME/.config/nvim" ]; then
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup-$(date +%Y%m%d-%H%M%S)"
fi
ln -s "$HOME/dot-files/neovim" "$HOME/.config/nvim"
```

### 3. Install the locked plugins and tools

Follow [Dependencies and updates](#dependencies-and-updates) below in order: bootstrap Lazy at its lockfile commit, install locked plugins, install the four pinned Mason tools, and compile the listed syntax parsers. Network access is needed for those explicit commands. If plugins/tools already exist on the destination Mac, follow the repair/restore commands there instead of cloning Lazy over them.

### 4. Add zsh integration

Add the following to `~/.zshrc` once, after other shell key bindings, then open a new terminal. The aliases and EDITOR/VISUAL settings reproduce the editor shell defaults; the hook is required for popup shell editing. It is not installed automatically by symlinking the config.

```zsh
alias vim='nvim'
alias vi='nvim'
export EDITOR='nvim'
export VISUAL='nvim'
bindkey '^R' history-incremental-search-backward
if [[ -n "$NVIM_POPUP_TERMINAL" ]]; then
  source "$HOME/.config/nvim/shell/popup.zsh"
fi
```

To use Caps Lock like Escape, open [System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys](https://support.apple.com/guide/mac-help/change-the-behavior-of-the-modifier-keys-mchlp1011/mac), select your keyboard, and set Caps Lock to Escape. Double Escape also works without this OS remapping.

### 5. Install agent CLIs for Sidekick

To reproduce both agent choices, install the [Codex CLI](https://formulae.brew.sh/cask/codex) and [Claude Code CLI](https://formulae.brew.sh/cask/claude-code), then run each once and finish its normal sign-in:

```sh
brew install --cask codex claude-code
codex
claude
```

These are optional for ordinary editing. Tmux is already installed by step 1 and provides Sidekick session persistence. Credentials are never copied from another Mac. No Copilot account is needed; AI completion/Next Edit Suggestions remain disabled.

### 6. Open your own project and verify

From any project you cloned or created on this Mac, run `nvim .`. No fixed project path is required. For Python, create/install that project’s `.venv` using its own instructions; a project-installed Python Pyright wrapper requires Python **3.11+** because it reads TOML with `tomllib`. Project dependencies and virtual environments are not dot files.

Run `:checkhealth`, `:checkhealth vim.lsp`, and `:ConformInfo`. Try Space `e` for the file tree, Space `sf`/`sg` for searches, Space `t` for the popup shell, and the Git/agent keys below. The branch comparison uses `origin/main` or `main` when available; projects with another default branch can change the Space `gm` mapping in `init.lua`. Run the [existing verification checks](#verification) after installing all dependencies.

## Daily use

The active file’s Git branch appears at the far right of the bottom statusline, after the cursor position. `mini.git` tracks branch switches automatically; only the branch name is shown, with `HEAD` when detached. Files outside Git repositories show no branch. Restart Neovim after changing the config.

Opening a Git folder with `nvim .` (or `nvim` from that folder) creates **Panel**, **Current Changes**, and **Changes against main** tabs immediately, leaving Panel focused. The comparison prefers `origin/main`, falls back to local `main`, and is skipped if neither shares history with HEAD. Click a tab to switch to it; double-clicking the tab bar does not create empty tabs. Tabs can be closed normally; `1`–`9` always follow their current positions and focus the editing/diff buffer instead of the side panel. Non-Git folders, explicit file opens, and restored multi-tab sessions keep their normal startup.

Start from your project: `cd /path/to/project && nvim .` (or `nvim app.py`). Space is the leader key. Automatic key hints are off by default. Press `?` in Normal mode to toggle them for the session; when on, press Space and pause for the key menu. Space `?` searches every mapping. The `?` toggle replaces Vim’s backward-search prompt.

| Keys | Action |
| --- | --- |
| `?` | Normal mode: toggle automatic key hints (default: off) |
| `1`–`9` | Normal mode: jump to that tab and focus its buffer (replaces numeric counts) |
| Space `e` | Toggle the left file tree; reveal the current file |
| `-` | Reveal the current file in the tree |
| Space Space | Open files by recent use; Enter switches to the previous file (or shows the current file if it is the only one open) |
| Space `sf` | Fuzzy file search, updated while typing |
| Space `st` | Live repository type/class search, including from the tree/start screen |
| Space `ss` | Fuzzy text search within the current buffer |
| Space `sg` | Live repository text search with ripgrep |
| `gd` or `grd` | Go to definition |
| `grt` | Go to type definition |
| `grr` | Find references |
| `K` | Type/documentation hover |
| `grn` / `gra` | Rename symbol / code actions |
| `[d` / `]d` | Previous/next error |
| Space `q` | Toggle the current-buffer error list |
| Space `f` | Format; Python also formats on save |
| Space `gd` | Git working-tree changes and side-by-side diffs |
| Space `gm` | Branch changes since diverging from `origin/main`, including current edits |
| Space `gh` | Git repository history |
| Space `gf` | Git current-file history |
| Space `gq` | Close the Git view and return to editing |
| Space `ut` | Preview/select themes; Catppuccin Mocha is the startup default |
| Ctrl `h/j/k/l` | Move between splits; in diff panes, Ctrl `j/k` jump to the next/previous change |
| Ctrl `d` / Ctrl `u` | Smooth scroll down/up 10 lines |
| Space `t` | Open the floating shell terminal |
| Caps Lock twice / Escape twice | Hide the floating shell terminal |

Space `q` opens/closes the error list, including when focused inside that list; it keeps errors underlined in the editor. Harpoon and the old Space `t` toggle group have been removed; Space `t` now opens the shell terminal. Space `e` toggles the file tree; `-` reveals the current file in it.

Modified, named, writable file buffers automatically save when Neovim loses focus (for example, switching to another app), including hidden buffers. Normal format-on-save hooks still run. Scratch, terminal, unnamed, and read-only buffers are skipped; write failures are reported as errors. This uses the terminal's focus events.

Search popups use 98% of the editor width, with equal-width results and preview panes in the horizontal layout.

The search menu contains exactly four keys: `sf` files, `st` types, `ss` current-buffer text, and `sg` repository text. Results update before Enter; Enter opens the selected result. Files and grep use the Git repository root even when editing a nested file. Ignored files such as `.venv` stay out of normal project search.

Type search uses Telescope and Pyright workspace symbols. It works from the start screen and file tree too: when necessary, it loads a Python file in the background to start the language server. Start typing a name; Pyright returns no symbols for an empty query. Results include class-like symbol kinds across the Python project; aliases reported by the server as variables are not included. Text search uses ripgrep patterns; files and current-buffer search support fuzzy matching. The old extra search mappings and aliases have been removed; `Space ?` remains shortcut help. Results selected from Neo-tree open in the editing window at the matched line.

Catppuccin includes Mocha, Macchiato, Frappé, and Latte. A theme picked interactively lasts for the session; change `flavour` in `init.lua` to change the startup default.

[Diffview](https://github.com/sindrets/diffview.nvim) opens changes or history in a dedicated tab, with its file/commit panel on the left. Select a file with Enter or double-click to open its side-by-side diff; Tab/Shift-Tab move between files. The two file panes share the available width equally after window resizing or returning to a diff tab, with the file panel retaining its width (odd column counts can leave a one-column difference). In a Diffview tab, Space `e` focuses its panel and Space `b` toggles it; Space `gq` returns to editing. Working-tree and branch comparisons use recursive filesystem notifications on macOS, grouping write bursts into one refresh after 300 ms. Only the visible view refreshes in Normal mode; unsaved buffers are preserved. Git index/ref changes are watched too, so staging and commits refresh Current Changes. Refreshes deferred while typing in a terminal resume when leaving it, including closing the popup. Diffview's built-in index polling is disabled; these refreshes are event-driven. Branch comparisons recheck their merge base on Git ref changes and when returning to the view. If a merge or ref update changes the base, the comparison reopens in the same tab position with the selected file preserved when it still has changes. This prevents changes inherited from main remaining in an already-open view. Git tabs are labeled `Current Changes`, `Changes against main`, or `History`; the help hint is hidden, but `g?` still opens the built-in help. In either diff pane, Ctrl `j` / Ctrl `k` jump to the next/previous changed block, continuing into the next/previous file at the boundary. Files without diff hunks are skipped; navigation wraps around the file list. Escape/Caps Lock in Normal mode does not navigate changes. Mouse-wheel/trackpad scrolling over either diff pane automatically focuses that pane and scrolls both sides together, vertically and horizontally; no click is needed. Long lines do not wrap in editing or diff views. Scroll sideways with the trackpad, or use native `zh`/`zl` (one column) and `zH`/`zL` (half a window) to pan left/right. Touchpad scrolling in editor and diff windows locks to the first horizontal or vertical direction, preventing diagonal drift. Pause briefly before changing axes (150 ms without scroll events); terminal mouse events do not report when fingers lift. Scrolling starts immediately, with no polling or timer. Files are shown in full, without collapsed code folds, both while editing and in Git diffs. The ordinary file tree remains unchanged.

[ToggleTerm](https://github.com/akinsho/toggleterm.nvim) opens your shell in a centered popup covering 90% of the editor. Press Space `t` in editor Normal mode to open the last-used session, ready for typing. Press Caps Lock twice (when mapped to Escape in macOS), or Escape twice, within 300 ms to hide it. A single Escape reaches the shell or running program; a double press hides the popup even while a command/editor is running. The popup stays in terminal input mode, including after ordinary mouse clicks; the native Ctrl Backslash, Ctrl N sequence also hides it. Hiding preserves the shell, running commands, working directory, and output for this Neovim session.

Its title shows nine terminal slots, with the current one in brackets. Click a number to switch shells; clicking the active number keeps it open. From the editor, use `:2ToggleTerm` through `:9ToggleTerm` to open another slot, or `:TermSelect` to select an existing session. Each shell starts on first selection. Spaces, numbers, and `t` remain ordinary terminal input. Outside the popup, Normal-mode numbers still switch editor tabs. `exit` ends that shell; selecting its slot again starts a fresh one. Click an HTTP/HTTPS link in its output to open it in your default browser; links must fit on one terminal line. This terminal is separate from Sidekick's agent sessions. Ctrl `r` searches shell history; press it again for older matches. The zsh binding is configured by the installation step above: `bindkey '^R' history-incremental-search-backward`. The popup zsh hook selects Emacs editing (`bindkey -e`) so Escape cannot put the shell line editor into Vi mode. Popup key handling no longer uses shell prompt events.

The installation step above includes this hook in `~/.zshrc`; keep it after other key bindings:

```zsh
if [[ -n "$NVIM_POPUP_TERMINAL" ]]; then
  source "$HOME/.config/nvim/shell/popup.zsh"
fi
```

Restart Neovim to load the new mappings and shell settings.

[Neoscroll](https://github.com/karb94/neoscroll.nvim) animates keyboard scrolling: Ctrl `d/u` keep their 10-line distance; Ctrl `b/f`, Ctrl `y/e`, and `zt`/`zz`/`zb` also animate. Mouse-wheel behavior remains native, including synchronized Git diff panes.

## Agents

[Sidekick](https://github.com/folke/sidekick.nvim) opens your installed agent CLIs in a right-hand terminal split. Install and authenticate Codex and Claude Code using the steps above; each CLI keeps its own login and permission settings. Start Neovim from the repository root: new agent sessions use the editor's current working directory.

| Keys | Action |
| --- | --- |
| Space `aa` | Show/hide the agent terminal; select a tool on first use |
| Space `as` | Select an installed agent or attach to a running session |
| Space `ad` | Detach the session from Neovim |
| Space `af` | Add the current file path to the agent's input |
| Space `av` (visual mode) | Add the selected code to the agent's input |
| Space `ap` | Pick a prompt or context to add |

Context and prompts fill the agent's input; press Enter there to submit. Inside the agent terminal, Ctrl `h` returns to the editor on the left, Ctrl `z` returns to the previous editor window, and Ctrl `q` enters terminal normal mode, where `q` hides the split. The normal double-Escape terminal escape also works.

Tmux keeps sessions running when hidden, detached, or after Neovim exits; Space `as` lets you reattach. To end an agent process, use that CLI's exit command. No Copilot account or extra completion plugin is needed. Sidekick's file watching refreshes files changed by agents.

On another machine, install `tmux` and your preferred agent CLI, then authenticate that CLI normally. After opening Sidekick once, `:checkhealth sidekick` checks the integration, but upstream also reports missing Copilot and optional CLIs even when using only installed agent tools; those are not required for this setup.

## Python environments

[Pyright](https://github.com/microsoft/pyright) is the only enabled LSP. It supplies type checking, hover, references, definitions, and symbols. Neovim selects the project-root `.venv/bin/python` without requiring shell activation. Root detection first looks for the nearest ancestor containing `.venv`, so monorepo packages share their workspace environment even when they have their own `pyproject.toml`. Without `.venv`, standard project markers such as `pyproject.toml`, `pyrightconfig.json`, `requirements.txt`, and `.git` determine the root. Each project gets its own server/environment.

The project’s `.venv/bin/pyright-langserver` is preferred, including environment/version settings from `[tool.poe.tasks.typecheck.env]`. Mason’s Pyright is the fallback for projects without a local checker. Diagnostic rules come from `pyrightconfig.json` or `[tool.pyright]`; there is no editor type-checking-mode or severity override. Only Pyright supplies Python diagnostics; Ruff handles formatting through Conform. Normal LSP completions use Blink; Ctrl Space requests completion and Ctrl Y accepts it.

Restart Neovim after changing this setup. Use `:checkhealth vim.lsp` to inspect attached servers, and `:lua =vim.lsp.get_clients({bufnr=0, name="pyright"})[1].settings.python.pythonPath` to inspect the interpreter (nil means Pyright’s default). The editor checks open files; run the repository’s typecheck task for the full project.

## Dependencies and updates

Tested with Neovim **0.12.4** on macOS. Treat upgrading Neovim itself as a separate change from plugin updates. External tools: Git, tmux, an agent CLI, ripgrep, fd, a C compiler/make, and Python/Node tooling. `uv` is used by the integration checks.

Normal startup does **not** install managed plugins, Mason tools, or syntax parsers, or check for plugin updates. Missing Tree-sitter highlighting falls back to ordinary syntax and reports a repair command once per filetype. Missing/failing formatters allow saving and report errors; `:ConformInfo` shows details. If the plugin manager is missing, Neovim starts with basic editing and an installation hint.

`lazy-lock.json` records plugin commits. The Mason setup in `init.lua` pins the installed fallback tools: Pyright **1.1.414**, Ruff **0.15.21**, StyLua **v2.5.2**, and Tree-sitter CLI **v0.26.11**. Project-installed Pyright still takes priority. The plugin lockfile does not pin Neovim, external runtimes, or project virtual environments.

On a new machine, install the external tools and symlink this repository’s `neovim` folder to `~/.config/nvim`. Bootstrap Lazy at the lockfile revision on a fresh installation (only when its directory is missing; create the parent directory first):

```sh
nvim_data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
nvim_config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
mkdir -p "$nvim_data/lazy"
git clone --filter=blob:none --no-checkout https://github.com/folke/lazy.nvim.git "$nvim_data/lazy/lazy.nvim"
git -C "$nvim_data/lazy/lazy.nvim" checkout "$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["lazy.nvim"]["commit"])' "$nvim_config/lazy-lock.json")"
```

Then explicitly install the locked plugins, pinned tools, and syntax parsers:

```sh
nvim --headless '+lua require("lazy").install({wait=true, lockfile=true})' +qa
nvim --headless '+MasonToolsInstallSync' +qa
nvim --headless '+lua require("nvim-treesitter").install({"python","bash","diff","lua","luadoc","markdown","markdown_inline","query","vim","vimdoc"}):wait(120000)' +qa
```

For repair, use `:Lazy restore` for installed plugins (the explicit install command above for missing ones), `:MasonToolsInstall`, or `:TSInstall python` (substitute the affected language). `:checkhealth vim.deprecated` catches configuration API deprecations; `:checkhealth` checks the broader environment. Health checks for lazy-loaded plugins may require opening their feature first. Missing Go/Rust/PHP runtimes are not needed for this Python setup.

**Updates:** start from a clean, committed configuration. Use `:Lazy update plugin-name` for a small related group, review its release notes and the lockfile diff, then run the checks below. Tree-sitter's `:TSUpdate` build hook aligns its parsers on plugin updates. Change Mason version pins deliberately and apply them with `:MasonToolsInstall`. Restart Neovim, exercise startup/search/Git in a real terminal, and commit only after the checks pass.

**Rollback:** revert the update commit, run `:Lazy restore` and `:MasonToolsInstall`, then `:TSUpdate` to align parsers with the restored plugin revision, and restart. These commands do not downgrade Neovim or external Python/Node runtimes; keep your previous runtime installer/version available when upgrading those separately. Avoid bundling a Neovim upgrade with tool and plugin updates. Agent maintenance guidance is in `AGENTS.md`.

## Verification

Run all checks from the `neovim` folder with the active config (temporary projects only; stop at the first failure):

```sh
(
  for nvim_test in tests/*.lua; do
    env -u VIRTUAL_ENV nvim --headless "+luafile $nvim_test" || exit 1
  done
)
```

The terminal-session check covers all nine slots through title clicks and ToggleTerm commands, single Escape reaching a nested commit editor, double Escape hiding the popup, Space `t` reopening it, terminal input after mouse clicks, literal space/number input, shell state/output persistence, returning to the last session, exit/recreation, resize, and editor-tab shortcuts. The startup resilience check verifies disabled automatic installs, fallback highlighting, visible formatter failures, and saving when formatting is unavailable. The workspace/tab, recent-file, and hint-toggle checks cover the customized navigation.

The Python check exercises two independent `.venv` environments (including a nested monorepo package), real dependency/type navigation, hover, cross-file references, workspace symbols, type diagnostics, and Python syntax parsing. The search check exercises all four pickers, unopened-file type results from a fresh session, and isolation between repositories. The diagnostics check verifies errors-only presentation, error-list toggling, and retention of the server's complete diagnostic data. The autosave check verifies FocusLost writes, normal save hooks, excluded buffers, and visible write failures. The commit-refresh check runs a real commit in the popup terminal and verifies that Current Changes clears after closing it without switching tabs. The branch-refresh check merges main into a feature branch and moves refs without changing files, verifying both diff panes, tab placement, and unsaved-buffer preservation. The diff-scroll check sends real mouse-wheel events over unfocused panes and verifies synchronized scrolling, direction locking, and ordinary-window behavior.

For Sidekick, check CLI startup, file/selection prefill, tmux detach/reattach, and refresh after an external file edit in a disposable project. Prefill does not submit a model request; press Enter only when you intend to send it.

## Upstream implementations

- [Joel's configuration and agent guide](https://github.com/joelhooks/dotfiles)
- [Sidekick agent integration](https://github.com/folke/sidekick.nvim)
- [Telescope](https://github.com/nvim-telescope/telescope.nvim) and [Neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [Pyright configuration](https://github.com/microsoft/pyright/blob/main/docs/configuration.md) and [Neovim LSP configuration](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/pyright.lua)
- [Tree-sitter setup](https://github.com/nvim-treesitter/nvim-treesitter), [Catppuccin](https://github.com/catppuccin/nvim), and [Conform](https://github.com/stevearc/conform.nvim)
