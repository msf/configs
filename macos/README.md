# MacBook bootstrap handoff

Target: M5 Max MacBook Pro, used for work and some personal tasks.
Status: preparation notes only. No Mac bootstrap is implemented or tested yet.

Goal: install a minimal starting environment, clone `~/configs`, then use agents
running natively on the Mac to configure the rest in stages. Keep each durable
change in the repository. A complete bootstrap script is not a prerequisite.

## First login

1. Complete employer enrollment; check Nix, personal VPN, and VM restrictions. Install Chrome and Bitwarden.
2. Install Xcode Command Line Tools with `xcode-select --install`; wait for installation to finish. This supplies Git.
3. Install Nix and Claude Code, then authenticate Claude Code. Nix can wait for agent-assisted setup if preferred.
4. Clone this repository into `~/configs`, start Claude Code there, and give it the prompt below. Clone `~/configs-private` when needed.

Use Safari for the initial downloads. Use HTTPS authentication to clone if SSH
access is not configured yet. Keep logins and permission approvals manual.

### Initial agent prompt

> Read `macos/README.md` and inspect this Mac and the existing configuration before
> changing anything. Do not run the legacy `install.py`.
>
> Set up this machine incrementally. Keep durable configuration in this repository
> and reuse the existing agent-resource manifest. Adopt tools already installed
> instead of creating competing installations.
>
> Start with packages, shell, terminal, and editors. Verify each stage and its
> repeatability before proceeding. Leave credentials, authentication, and permission
> approvals outside Git. Ask before changing SSH access, enabling wiki
> synchronization, or modifying disks.

The agent must update configuration, not just run installation commands. Incorporate
manually installed applications into the chosen package inventory; do not uninstall
and reinstall them solely to claim ownership. Report remaining manual steps.

**Do not run the existing root `install.py`.** It removes existing matching home
paths before linking repository dotfiles. This includes directories such as `.ssh`
and `.claude`, which can contain credentials and machine-local state.

Existing trusted SSH access to the home server can help authorize the new machine.
A dedicated Mac key can be generated on the existing laptop and authorized before
arrival. Transfer it through an authenticated encrypted connection, then remove the
staging copy; backups can retain copies. Generating the key on the Mac is optional.
Keep private keys out of both configuration repositories.

## Proposed configuration ownership

These are recommendations, not finalized or deployed choices.

| Layer | Owner |
| --- | --- |
| CLI packages and selected macOS preferences | Thin nix-darwin configuration with a committed flake lock |
| Mac GUI applications | Homebrew casks declared through nix-darwin |
| Project toolchains | Project configuration; one owner per toolchain |
| Dotfiles | Existing repository, with explicit Mac-compatible file selection |
| Agent resources | Existing `ai-agents/tools/manifest.txt` and deployment tools |
| Credentials and trust decisions | Local Keychain or application credential stores, never Git |
| Work-specific configuration | Optional `~/configs-private` checkout |
| Enrollment and privacy permissions | Explicit manual checklist |

Homebrew declarations reproduce an application inventory, not exact versions.
Nix-darwin does not reproduce all macOS state or roll back the operating system.
If this becomes too much maintenance, use a Brewfile plus existing dotfiles and
reserve Nix for project environments. Do not maintain both approaches in parallel.

Use native `aarch64-darwin` packages. Avoid an Intel Homebrew installation unless a
specific dependency requires one. Keep `$HOME` portable; macOS uses `/Users/...`,
not `/home/...`.

## Agent-driven setup stages

Implement and verify one stage at a time on the Mac. Extract repeatable steps into
small scripts or declarative configuration as they become known. Do not require a
monolithic installer, another configuration framework, or another agent manifest.

1. Inventory installed tools; configure packages, shell, terminal, and editors.
2. Apply selected dotfiles and existing managed agent resources; complete their authentication.
3. Configure approved homelab access and test wiki replication before enabling it.
4. Configure Colima and the separate Linux VM; verify both and record remaining manual steps.

Required behavior:

- Check macOS and architecture before making changes.
- Preserve existing files; back up replacements and reject ambiguous ownership.
- Resume after failure. A second run must not recreate identities or reset VM data.
- Keep OS updates, credential enrollment, and destructive disk operations out of automatic activation.

Read [the agent deployment documentation](../ai-agents/tools/README.md) before
integrating its existing apply, dependency-installation, and verification steps.
Check those scripts on macOS; do not assume Linux success proves portability.
Audit shell configuration, absolute paths, GNU utility assumptions, launch services,
and browser/tool dependencies. Do not copy entire `.ssh`, `.claude`, `.codex`, or
`.pi` directories from another machine.

The existing repository has unrelated local changes. Do not reset or absorb them
into bootstrap work. Before leaving the old laptop, review and explicitly commit
and push the intended handoff/configuration changes; uncommitted files do not reach
a fresh clone.

## Software inventory

| Category | Required or proposed software |
| --- | --- |
| Network and identity | Tailscale, employer-managed Okta, Bitwarden |
| Browsers and communication | Chrome, Firefox, Discord |
| Terminal and editors | Ghostty, tmux, Neovim, VS Code |
| Development | Git, Go, Rust, GNU make, Xcode Command Line Tools |
| Coding agents | Claude Code, Codex, Pi; one supported installation mechanism each |
| Containers | Colima, Docker CLI, Compose plugin; verify `docker compose` works |
| Linux development | Separate Lima ARM64 VM with root access and a dedicated virtual data disk |
| Monitoring | htop, btop; macOS native diagnostic tools |
| Window management | Rectangle for snapping, or AeroSpace for automatic tiling; choose one |
| SSH server | Built-in Remote Login, only if inbound access is needed |

Useful additions: ripgrep, fd, fzf, jq, yq, direnv, gh, uv, a maintained Node runtime,
pkg-config, CMake, Ninja, ShellCheck, and shfmt. Install GNU utilities selectively;
do not blindly replace every system command.

If Rust uses rustup, commit project `rust-toolchain.toml` files rather than also
installing a competing Rust toolchain through another manager.

## Homelab access and wiki replication

Use Tailscale plus ordinary OpenSSH to connect directly to the home server.
The existing laptop must not be required as a relay. Keep hostnames, addresses,
access rules, and private SSH configuration outside this public handoff.

Multiple keys can remain loaded in the SSH agent. Do not require per-host identity
selection unless account ambiguity or authentication-attempt limits make it useful.
Keep the wiki-sync identity restricted separately from interactive access.

Use Apple's OpenSSH integration with the login keychain for key passphrases. Private
key files remain under `~/.ssh`; Keychain does not replace those files. Keep shared
SSH configuration compatible with Linux by ignoring the Apple-only `UseKeychain`
option there.

Enable connection multiplexing with a private `~/.ssh/cm` directory. Enable agent
forwarding for explicitly trusted hosts where remote Git or SSH needs it, not for
every destination. Remote privileged processes can use the forwarded agent while
connected. A persistent multiplexed connection can outlive the interactive shell.

Ghostty's SSH shell wrapper currently attempts terminfo setup even for control
commands. Use `command ssh -O check <host>` or `command ssh -O exit <host>` to bypass
that function. An absent control socket means there is no master at that path.
Provision remote Ghostty terminfo deliberately rather than relying on the wrapper.

Check corporate VPN compatibility and limit the work laptop's homelab access to
the required services.

Extend the existing Unison setup rather than adding a second sync system:

```text
existing laptop ~/wiki <-> home-server wiki <-> Mac ~/wiki
```

The server is the shared synchronization point, not an authority that overwrites
laptop edits. Each client needs its own archive, identity, and local state.

Before enabling scheduled synchronization:

- Review which personal/work content belongs on this employer-managed device.
- Check case and Unicode filename collisions before seeding the Mac filesystem.
- Use compatible Unison versions and preserve the existing exclusion rules.
- Serialize server-side reconciliation across clients; a laptop-local lock is insufficient.

Use a launchd user job instead of a systemd timer. Provide manual sync and status
commands. Preserve both versions of unresolved conflicts. Basic sync must not
require an LLM provider; a missing conflict arbiter must not lose content.

Consult the existing wiki's `tooling/concepts/wiki-sync.md` for implementation paths
and exclusions, then verify actual runtime state. Some historical migration warnings
were stale when checked during this discussion. Do not copy Unison archives,
credentials, Git internals, or raw imports as part of the initial seed.

Test two-client edits, overlapping edits, deletions, offline operation, and concurrent
sync attempts on disposable roots before enabling writes to the real wiki.
Server snapshots/backups remain necessary: synchronization also propagates mistakes.

## Linux VM and storage work

Keep the Linux development VM separate from Colima. Kernel crashes must not take
down the everyday container environment. Keep Linux source/build trees inside the
guest filesystem and connect through SSH or VS Code Remote SSH.

Use an ARM64 guest with a recent kernel. Confirm whether the project is a kernel
block driver, a userspace ublk/io_uring backend, or an actual hardware driver before
choosing the storage attachment strategy.

A disk-image-backed guest block device supports Linux block APIs and io_uring.
It is not physical-device passthrough. A host partition exposed through virtio also
retains virtualization and does not expose the actual NVMe controller.

Do not repartition the boot SSD in the bootstrap. Physical block-device attachment
in Lima was pending in [PR #5117](https://github.com/lima-vm/lima/pull/5117) when
checked; recheck released support before relying on it. Test any attachment path
with expendable external storage first. Use real Linux hardware for authoritative
hardware-specific and storage-performance measurements.

## Manual settings and acceptance checks

Keep FileVault, SIP, Gatekeeper, and security updates enabled by default. Grant
Developer Tools permission to trusted development applications only when needed.
This is not a guarantee that macOS makes no online trust checks. Avoid blanket
quarantine removal and unreviewed debloat scripts.

Record chosen key repeat, Caps Lock mapping, smart punctuation/autocorrect, Spaces,
analytics, and cloud settings. Record required Accessibility, Local Network, and
other application permissions. Avoid granting Full Disk Access indiscriminately.

Before calling the bootstrap complete, verify:

- A clean machine reaches a working shell, editors, and requested applications;
  repeating activation does not unexpectedly change local state.
- Agent manifest verification and the existing resource audit pass on macOS;
  authentication works without copying session history or trust databases.
- SSH reaches the intended server, wiki sync converges, and held conflicts are visible.
- A Compose smoke test works; the separate guest has root and the required kernel
  features; host keys and disk data survive a second bootstrap run.

## Deferred follow-up

Review web-search provider/model routing separately. It was flagged during the
planning session and is not part of the Mac bootstrap implementation.
