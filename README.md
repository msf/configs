# configs

Dotfiles and agent configuration shared by several Linux hosts and a macOS work laptop. `ai-agents/tools/manifest.txt` declares what each host deploys; `ai-agents/tools/README.md` explains it.

## Working across machines

Authored by LLM.

1. Before you edit on a host, run `git pull`. The global `pull.rebase = true` rebases local commits onto `origin`.
2. Commit small changes and push at the end of the session, so hosts don't drift apart.
3. Where practical, keep host-specific settings out of shared files: use manifest `@host` / `@!host` selectors, `ai-agents/hosts/<host>/`, or `includeIf` in `.gitconfig`. When a shared change breaks another host, say so in the commit message and fix it on that host.
4. After each pull, run `ai-agents/tools/apply.sh`, then `ai-agents/tools/apply.sh --verify`.

## Legacy notes

This is a collection of .*rc files and sometimes something more.

MacBook setup: read macos/README.md first. The legacy install.py below removes
existing home paths, including directories; do not use it to bootstrap the Mac.

issue:
$ find . -not   -path   "./.git*"  -type f |xargs -I a md5sum  a ~/a

to find whats different from current system.
RUN:
$ python install.py
$ ./install_vundle.sh

