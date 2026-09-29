{ ... }:

{
  imports = [
    ./packages.nix
    ./homebrew.nix
    ./defaults.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Without HostName, the shell prompt shows a DHCP-derived name.
  networking.hostName = "liskov";
  networking.localHostName = "liskov";
  networking.computerName = "liskov";

  system.primaryUser = "miguel";
  users.users.miguel.home = "/Users/miguel";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "@admin" ];
  };
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # /etc/zshrc with Nix paths. ~/.zshrc (from this repo) guards its own compinit.
  programs.zsh.enable = true;

  # Touch ID for sudo, also inside tmux.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Read `darwin-rebuild changelog` before changing this.
  system.stateVersion = 6;
}
