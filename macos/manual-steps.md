# macOS manual steps

Steps that need a password, a GUI approval, or a protected settings domain.
Everything else is in `darwin/` (nix-darwin) or `link-dotfiles.sh`.

## 1. Install Nix and apply the configuration

```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

Open a new terminal, then run the first activation (later runs: `sudo darwin-rebuild switch --flake ~/configs/macos#liskov`):

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin/master#darwin-rebuild -- switch --flake ~/configs/macos#liskov
```

If activation stops on "Unexpected files in /etc", rename each listed file to
`<name>.before-nix-darwin` (for example `sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin`) and run it again.
Commit the generated `flake.lock`.

## 2. Dotfiles

```bash
~/configs/macos/link-dotfiles.sh
```

## 3. SSH keys in the login keychain

One time; enter each passphrase once. Afterwards `ssh` loads the keys from
Keychain without prompting, including after a reboot.

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_fw13
```

Bitwarden stays for passwords only:

- Bitwarden > Settings: turn off **Enable SSH agent**. Then `rm ~/.bitwarden-ssh-agent.sock`.
- Keep one Bitwarden copy. `/Applications/Bitwarden 2.app` is a second (App Store) install; move one to the Trash.

## 4. Appearance (protected settings domains)

System Settings > Accessibility > Display:

- Reduce motion: on
- Reduce transparency: on (removes most Liquid Glass blur)
- Increase contrast: on (adds borders; optional)

System Settings > Appearance: Liquid Glass **Tinted**, sidebar icon size Small.

macOS offers no setting for window corner radius.

## 5. Privacy

- Privacy & Security > Analytics & Improvements: turn everything off.
- Privacy & Security > Apple Advertising: off.
- Spotlight: turn off "Help Apple improve Search" and the categories you do not use.
- Apple Intelligence & Siri: off, unless wanted.

## 6. Permissions

- Rectangle: Accessibility (prompted at first start).
- Ghostty: grant Developer Tools only if needed.
- Do not grant Full Disk Access broadly.

## 7. Git over SSH

After step 3, add `~/.ssh/id_ed25519.pub` to GitHub if it is not there, then:

```bash
git -C ~/configs remote set-url origin git@github.com:msf/configs.git
```
