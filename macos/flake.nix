{
  description = "nix-darwin configuration for liskov (M5 Max MacBook Pro)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nix-darwin, ... }: {
    # Apply: sudo darwin-rebuild switch --flake ~/configs/macos#liskov
    darwinConfigurations.liskov = nix-darwin.lib.darwinSystem {
      modules = [ ./darwin ];
    };
  };
}
