# Neovim configuration

Install this config by symlinking this repository’s neovim folder to ~/.config/nvim.
Based on Joel Hooks' Kickstart config; provenance and upstream links are in README.md.

- Keep existing plugin implementations and their documented settings; avoid custom frameworks.
- ty supplies navigation, hover, completion and symbols with its diagnostics discarded; Pyright supplies only diagnostics, with its other capabilities removed. Detect each project-root .venv dynamically for both; prefer project-installed ty, and project-installed Pyright with its Poe typecheck environment. Preserve project Pyright rules without global diagnostic overrides. Ruff's language server runs only where the repository configures Ruff, preferring the project's Ruff; lua_ls (with lazydev) covers Lua.
- Preserve lazy-lock.json. Update only dependencies relevant to the requested change and verify them.
- Show errors only in diagnostic UI and notifications, with underlines/markers but no inline diagnostic text; preserve project type-checking rules and underlying diagnostic data.
- Sidekick provides agent CLI sessions with tmux persistence. Keep NES/AI autocomplete disabled and retain normal CLI permission prompts.
- Use a disposable Git/Python project for destructive Git tests; never discard user work for testing.
- Validate startup, Python LSP and .venv imports, live search, the file tree, and Git views after changes.
- Keep runtime caches, local environments, credentials, and test outputs out of this repository.
- Update README.md when changing keys or setup steps.
