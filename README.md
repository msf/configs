# configs

A collection of .*rc files and sometimes something more, shared by several Linux hosts and a macOS work laptop. `ai-agents/tools/manifest.txt` declares the agent configuration each host deploys; `ai-agents/tools/README.md` explains it. MacBook setup: read `macos/README.md` first.

## Working across machines

Authored by LLM.

1. Before you edit on a host, run `git pull`. The global `pull.rebase = true` rebases local commits onto `origin`.
2. Commit small changes and push at the end of the session, so hosts don't drift apart.
3. Where practical, keep host-specific settings out of shared files: use manifest `@host` / `@!host` selectors, `ai-agents/hosts/<host>/`, or `includeIf` in `.gitconfig`. When a shared change breaks another host, say so in the commit message and fix it on that host.
4. After each pull, run `ai-agents/tools/apply.sh`, then `ai-agents/tools/apply.sh --verify`.

## New machine

Authored by LLM.

1. Install git, zsh, neovim, tmux, ripgrep, fd, and a C compiler.
2. Clone the repository: `git clone git@github.com:msf/configs.git ~/configs`. Use the HTTPS URL if the host has no SSH key yet.
3. Run `~/configs/macos/link-dotfiles.sh` (`--dry-run` previews it). Despite its path, it works on Linux too. It links zsh, git, tmux, nvim, kitty, ghostty, and the common `bin/` scripts, creates `~/.ssh/config` with the shared include, and moves displaced files to `<path>.bak.<timestamp>`. Run it only on a fresh home: on hosts where `~/bin` is a symlink into this repository, it renames repository files.
4. Make zsh the login shell: `chsh -s "$(command -v zsh)"`.
5. Deploy the agent configuration: `~/configs/ai-agents/tools/apply.sh`.
6. On a Linux desktop with sway, link its configuration:

   ```sh
   ln -s ~/configs/sway ~/.config/sway
   for d in i3status-rust mako kanshi fuzzel swaylock xdg-desktop-portal; do ln -s ~/configs/sway/$d ~/.config/$d; done
   ```

### Neovim

1. Start `nvim` once. It clones lazy.nvim and installs the plugins.
2. Run `:Lazy restore` to pin the plugins to `lazy-lock.json`.
3. Install the LSP servers through Mason: `:MasonInstall gopls golangci-lint-langserver rust-analyzer`. `golangci-lint-langserver` also needs `golangci-lint` on `PATH`.

Treesitter compiles its parsers with the C compiler (`:TSUpdate`), and Telescope uses ripgrep and fd.
