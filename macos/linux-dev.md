# Ubuntu development VM

`darwin/linux-dev.yaml` defines a persistent Ubuntu 26.04 ARM64 VM for Linux
storage development. Lima is already in `darwin/packages.nix`. The VZ backend
does not need host QEMU; QEMU for nested ARM guests is installed inside Ubuntu.

The VM has 8 CPUs, 16 GiB RAM, a 128 GiB system disk and a separate 250 GiB scratch
disk. It enables nested virtualization and uses `miguel` with home `/home/miguel`.
It shares only the Mac directories
listed below and runs no container runtime. Linux builds and test backing files
remain on its native filesystem.
Both virtual disks grow as they are used; their capacities are not reserved space.

## Coexistence with OrbStack

OrbStack remains the Docker runtime. Do not change the Docker context, Docker
socket, OrbStack settings, or start Colima as part of this VM setup.

The VM uses Lima's private user-mode network, with no extra shared or bridged
network. From Ubuntu, `host.lima.internal:<port>` reaches Mac services, including
listeners bound to Mac loopback. From macOS, `127.0.0.1:<port>` reaches guest TCP
and UDP services on ports 1024–65535. Lima publishes these only on Mac loopback,
not on the LAN. This is forwarding between separate network stacks, not shared
loopback; each machine's `localhost` still refers to itself.

A port already occupied on macOS cannot also forward a guest service. Choose
another guest port when it conflicts with OrbStack or a Mac service. Lima keeps
a separate dynamic SSH port. Privileged guest ports are not published.

## Start and enter

Create it once:

```sh
limactl disk create linux-scratch --size 250GiB --format raw
limactl start --name=linux-dev ~/configs/macos/darwin/linux-dev.yaml
```

After the first successful boot, give the development user access to scratch
and disable automatic scratch-disk formatting:

```sh
limactl shell linux-dev -- sudo chown miguel:miguel /mnt/lima-linux-scratch
limactl stop linux-dev
limactl edit --tty=false --set='.additionalDisks[0].format = false' linux-dev
limactl start linux-dev
```

Do not recreate an existing disk. Its contents persist across VM stops.

After creation:

```sh
limactl start linux-dev
linux
# Equivalent: shlinux or limactl shell linux-dev
```

The Mac's zsh configuration defines both aliases. Open a new shell or run
`source ~/.zshrc` to load them. They enter a running VM; start it first if stopped.

Inside Ubuntu, use `tmux` to keep editors and sessions alive across disconnects.
Stop the VM from macOS with `limactl stop linux-dev`. Changes to the repository
YAML do not update an existing instance automatically. Do not delete the instance
to apply changes: its disk contains the checkout and other persistent work.

## Shared folders

Lima exposes these directories through virtiofs:

| Mac directory | Ubuntu directory | Access |
| --- | --- | --- |
| `~/rlwy` | `/home/miguel/macos/rwly` | Read-only |
| `~/Downloads` | `/home/miguel/macos/Downloads` | Read-only |
| `~/Documents` | `/home/miguel/macos/Documents` | Read-only |
| `~/play` | `/home/miguel/macos/play` | Read-only |
| `~/wiki` | `/home/miguel/macos/wiki` | Read-only |

The actual Mac directory is spelled `rlwy`; the guest keeps its existing `rwly`
mount point. Keep builds and storage-test backing files on the guest disks.
These mounts do not expose the whole Mac home or OrbStack's Docker socket.
Read-only access still lets guest processes read any secrets in these directories.

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
Zsh loads the repository through `~/.config/zsh/home-setup.zsh`; Lima can append
its boot-time PATH block there without modifying the Git checkout.

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

Authenticate on macOS with Pi's `/login` or `/mcp login <server>`. Stop Pi
sessions in the VM, then copy the main profile's credential stores from macOS:

```sh
bash ~/configs/macos/sync-pi-auth.sh
```

The script copies `~/.pi/agent/{auth,mcp-auth}.json` over SSH to `linux-dev`.
Pass another Lima instance name as its only argument if needed. It validates
JSON, replaces each guest file atomically with mode `0600`, and does not print
credentials. Missing source files leave the corresponding guest files unchanged.
Existing stores are replaced, not merged. Restart guest Pi sessions afterwards.

Repeat after re-authenticating on the Mac. OAuth refresh-token rotation can make
one copy stale when the other refreshes; these are copies of the same credentials,
not independent logins. External keychain commands and environment secrets are
not transferred.

MCP credentials require the same server names and URLs in the guest's MCP
configuration. This script copies neither server definitions nor browser cookies.
The public agent configuration is deployed through its manifest;
`~/configs-private` and work integrations remain separate.

### Mac-local Qwen from Ubuntu

The guest's main and lean Pi profiles use
`http://host.lima.internal:8090/v1` for the `local` provider. The Mac profiles
keep `http://localhost:8090/v1`. This guest-specific change lives in the guest's
config checkout; preserve it when updating that checkout. For a new guest, change
only `providers.local.baseUrl` through `~/.pi/agent/models.json` and
`~/.pi/agent-lean/models.json` to the guest URL.

Inside Ubuntu:

```sh
curl --fail --silent http://host.lima.internal:8090/v1/models | jq '.data[].id'
pi --model local/qwen38-27b
```

The Mac's llama.cpp server must be running. No LAN listener or SSH tunnel is
needed for this connection.

Run the agent checks inside Ubuntu:

```sh
~/configs/ai-agents/tools/apply.sh --verify
uv run --quiet ~/.agents/skills/pi-skill-import/scripts/audit.py
```

The initial public-only bootstrap did not pass these checks: the manifest
verifier reported absent private resources and optional lean-profile state;
the audit reported the absent private lessons journal and unavailable provider
models. Recheck model availability after syncing auth. Do not create placeholder
files or copy unrelated secrets merely to silence these checks.

Verified on 2026-10-14: default Lima zsh login, shared prompt and aliases, tmux
options and key bindings, Neovim startup and pinned plugins, rust-analyzer
initialization, Chromium HTTPS rendering with Pi's persistent profile, and a
repeated bootstrap without additional dotfile backups.

## Storage testing

`linux-scratch` is a separate sparse 250 GiB raw virtual disk on the Mac at
`~/.lima/_disks/linux-scratch/datadisk`. Lima initially partitions it and creates
ext4 at `/mnt/lima-linux-scratch`. The development user owns that filesystem.
The live instance has `additionalDisks[0].format: false` after initialization,
so a later boot cannot automatically format it if an experiment removes its label.

Use `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS` to identify its block device.
Unmount `/mnt/lima-linux-scratch` before destructive block-device experiments.
Do not overwrite the root device. If an experiment removes the ext4 partition,
Lima cannot mount it on the next boot; restore the filesystem when needed.

Keep this VM's system disk and credentials separate from disposable test disks.
Nested guests must use ARM64 images and `qemu-system-aarch64 -accel kvm -cpu host`.
Verified on 2026-10-16 after restart: five read-only mounts and rejected write
probes, scratch-disk size and read/write I/O, both shell aliases, TCP and UDP in
both directions, and an actual Pi request to `local/qwen38-27b` returning
`VM_QWEN_OK`. Guest services were bound only to Mac `127.0.0.1`.
Evidence: `~/.local/state/linux-dev/2026-10-16-expansion/` on the Mac and
`~/.local/state/linux-dev/` in Ubuntu.

The agent-config checks remain non-green. The Mac verifier reports unrelated
mail, lean-bin and MCP projection differences; its Pi audit reports stale Slack
and MCP bridge resources. The guest checks report absent private resources and
its missing lessons journal. These were not changed by the VM expansion.

The storage project's current x86 KVM boot probe needs adaptation for ARM.
Verified on 2026-10-14: Ubuntu boot and restart, GitHub HTTPS and SSH as `msf`,
config-repository clone, push dry run, and unprivileged nested KVM initialization.
The kernel provides `ublk_drv` and enables io_uring. No nested OS boot or storage
project test suite has run.
