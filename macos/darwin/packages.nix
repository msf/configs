{ pkgs, ... }:

let
  # Not in the pinned nixpkgs; use Notion's native macOS release.
  ntn = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "ntn";
    version = "0.23.26";

    src = pkgs.fetchurl {
      url = "https://ntn.dev/releases/v${version}/ntn-aarch64-apple-darwin.tar.gz";
      hash = "sha256-bczJzc+tmzj6WXdQl/+mw0wwbPufV06peHM3rwSX1fg=";
    };

    dontBuild = true;
    dontStrip = true; # Preserve the upstream Mach-O code signature.
    installPhase = ''
      runHook preInstall
      install -Dm755 ntn "$out/bin/ntn"
      runHook postInstall
    '';

    meta.platforms = [ "aarch64-darwin" ];
  };
in
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
    poppler-utils # pdftotext for Pi web_read
    ntn # official Notion CLI

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
