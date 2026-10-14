# Ubuntu development VM

`darwin/linux-dev.yaml` defines a persistent Ubuntu 26.04 ARM64 VM for Linux
storage development. Lima is already in `darwin/packages.nix`. The VZ backend
does not need host QEMU; QEMU for nested ARM guests is installed inside Ubuntu.

The VM has 8 CPUs, 16 GiB RAM, a 128 GiB virtual disk, nested virtualization,
and user `miguel` with home `/home/miguel`. It mounts no Mac directories and
runs no container runtime. Source and build trees live on its Linux filesystem.
The virtual disk grows as it is used; 128 GiB is its capacity, not reserved space.

## Coexistence with OrbStack

OrbStack remains the Docker runtime. Do not change the Docker context, Docker
socket, OrbStack settings, or start Colima as part of this VM setup.

The VM uses Lima's private user-mode network, with no extra shared or bridged
network. Automatic TCP and UDP port forwarding is disabled to leave localhost
service ports available for OrbStack. Lima still allocates a free loopback port
for SSH. Publish any future VM service through an explicit, unused SSH tunnel
rather than enabling automatic forwarding.

## Start and enter

Create it once:

```sh
limactl start --name=linux-dev ~/configs/macos/darwin/linux-dev.yaml
```

After creation:

```sh
limactl start linux-dev
limactl shell linux-dev
```

Inside Ubuntu, use `tmux` to keep editors and sessions alive across disconnects.
Stop the VM from macOS with `limactl stop linux-dev`. Changes to the repository
YAML do not update an existing instance automatically. Do not delete the instance
to apply changes: its disk contains the checkout and other persistent work.

## SSH and GitHub

This trusted development VM forwards the Mac's SSH agent. Private keys stay on
the Mac. Guest processes, including root, can use the forwarded identities while
the agent is available. Do not extend forwarding to disposable test guests.

Load the Mac identities through Keychain if needed:

```sh
ssh-add --apple-use-keychain ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_fw13
```

Lima exposes the forwarded agent at `/run/host-services/ssh-auth.sock` in the
guest. If an existing tmux session has a stale agent path, set it there:

```sh
export SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock
ssh-add -l
ssh -T git@github.com
```

GitHub's successful SSH greeting exits with status 1 because it offers no shell.
Git authentication does not authenticate the `gh` API client; use `gh auth login`
separately if API or pull-request commands are needed.

This instance has `git@github.com:msf/configs.git` cloned into `/home/miguel/configs`.
For a new instance, verify GitHub's host key before accepting it, then clone:

```sh
git clone git@github.com:msf/configs.git ~/configs
```

The clone does not copy the Mac checkout's uncommitted changes. Use the home
setup below to deploy dotfiles and public agent resources. Do not run the legacy
`install.py`.

To check push negotiation without changing a remote branch, run inside the clone:

```sh
git push --dry-run origin HEAD
```

A dry run checks access to GitHub's receive-pack service. It does not prove that
branch rules will permit a particular future update.

## Home environment

Inside Ubuntu, run:

```sh
bash ~/configs/linux/setup-home.sh
```

This links the shared zsh prompt, aliases, Git settings, tmux configuration and
Neovim configuration. It installs Neovim 0.12.5, Pi 1.1.0, uv 0.12.17, Rust,
Go, editor tools and Ubuntu's Chromium snap. The browser profile lives under
`~/snap/chromium/common/pi-profile`, linked from Pi's normal profile path, because
Snap cannot write directly under `~/.pi`. Neovim plugins restore from
`nvim/lazy-lock.json`. Replaced home files are backed up under
`~/.local/state/home-setup/`. SSH files and credentials are not replaced.

After installation, stop the VM and select zsh in Lima from macOS:

```sh
limactl stop linux-dev
limactl edit --tty=false --shell=/usr/bin/zsh linux-dev
limactl start linux-dev
infocmp -x xterm-ghostty | limactl shell linux-dev -- tic -x -
```

The initial image uses bash because zsh is installed during provisioning.
Changing the Linux login shell alone does not change Lima's shell setting.
Ghostty terminfo is copied from the Mac, not replaced with `TERM=xterm-256color`.

Start Pi inside Ubuntu and use `/login` for provider authentication. The public
agent configuration is deployed through its manifest; `~/configs-private`,
provider tokens, browser cookies and work integrations are not copied. The
Mac-local LLM at `127.0.0.1:8090` is not exposed to the guest.

Run the agent checks inside Ubuntu:

```sh
~/configs/ai-agents/tools/apply.sh --verify
uv run --quiet ~/.agents/skills/pi-skill-import/scripts/audit.py
```

These checks are not fully green on a public-only, unauthenticated installation:
the manifest verifier reports absent private resources and optional lean-profile
state; the audit reports the absent private lessons journal and unavailable
provider models. Do not copy secrets or create placeholder files to silence them.

Verified on 2026-10-14: default Lima zsh login, shared prompt and aliases, tmux
options and key bindings, Neovim startup and pinned plugins, rust-analyzer
initialization, Chromium HTTPS rendering with Pi's persistent profile, and a
repeated bootstrap without additional dotfile backups.

## Storage testing

Keep this VM's system disk and credentials separate from disposable test disks.
Nested guests must use ARM64 images and `qemu-system-aarch64 -accel kvm -cpu host`.
The storage project's current x86 KVM boot probe needs adaptation for ARM.
Verified on 2026-10-14: Ubuntu boot and restart, GitHub HTTPS and SSH as `msf`,
config-repository clone, push dry run, and unprivileged nested KVM initialization.
The kernel provides `ublk_drv` and enables io_uring. No nested OS boot or storage
project test suite has run.
