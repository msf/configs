{ pkgs, ... }:

# CLI tools. GUI applications live in homebrew.nix.
# Kept from the base system instead: git (Xcode CLT), jq (/usr/bin/jq).
{
  environment.systemPackages = with pkgs; [
    # shell and terminal
    bash # macOS ships bash 3.2; repo scripts use `#!/usr/bin/env bash`
    tmux
    fzf
    direnv
    tree
    wget
    watch

    # editors
    neovim

    # git
    delta # core.pager in .gitconfig
    git-lfs # filter.lfs in .gitconfig
    gh

    # search and data
    ripgrep
    fd
    yq-go

    # development
    go
    rustup # projects pin toolchains with rust-toolchain.toml
    uv
    nodejs_24
    gnumake
    pkg-config
    cmake
    ninja
    shellcheck
    shfmt
    gitleaks
    trufflehog

    # monitoring
    htop
    btop
    ncdu
    smartmontools

    # carried over from the nixos/ machines
    awscli2
    rclone
    restic
    mbuffer
    zstd
    weechat

    # Linux VMs (VZ does not require host QEMU)
    lima

    # containers (separate from the Linux development VM)
    colima
    docker-client
    docker-compose
  ];

  fonts.packages = with pkgs; [
    dejavu_fonts # ghostty/config
    inconsolata
    liberation_ttf # .gitconfig gui.fontui
    source-code-pro
    powerline-fonts
  ];
}
