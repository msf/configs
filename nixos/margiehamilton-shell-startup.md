# Margie Hamilton shell startup follow-up

Measured on NixOS 21.11 before the staged reboot to 23.11:

- `ssh ... true`: 0.45 s
- interactive `zsh -f` (startup files disabled): 0.55 s
- normal interactive zsh: 6.42 s
- `compinit`: 4.88 s (96.68% of profiled time), called three times
- `compdump`: 2.60 s, called twice

The three completion initializations come from:

1. `/etc/zshrc`: NixOS `programs.zsh` completion setup
2. `/etc/zshrc`: Oh My Zsh, which initializes completion again
3. `~/.zshrc:17-18`: explicit `autoload -Uz compinit; compinit`

The prompt was not measurably responsible. Secondary startup work includes keychain (and a warning for missing `~/.ssh/miguel_dune`), kubectl completion, pyenv, SDKMAN, NVM, fzf, Wasmer, Bun, and `~/.zsh_prompt`.

## Proposed follow-up

After the 23.11 upgrade, profile again while the host is idle. The minimal host-specific fix is to disable NixOS completion and Oh My Zsh on Margie, leaving the single completion initialization in the shared `~/.zshrc`:

```nix
programs.zsh.enableCompletion = false;
programs.zsh.ohMyZsh.enable = false;
```

Then remove the stale keychain key reference and measure again before considering lazy-loading NVM or other toolchains. Target: normal interactive startup under 2 seconds on this hardware.

No shell-startup fixes were applied during the OS upgrade session.
