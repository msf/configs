{ ... }:

# Homebrew packages through the existing /opt/homebrew installation.
#
# Installed manually before this configuration, adopted as-is and not
# re-declared (Homebrew refuses to overwrite an existing app):
#   Firefox, Google Chrome, Bitwarden, Claude, Tailscale, Telegram, Kindle
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # Never remove apps that are not listed here.
      cleanup = "none";
    };

    brews = [ "pgcli" ];

    casks = [
      "1password"
      "discord"
      "ghostty"
      "gimp"
      "kitty"
      "localsend"
      "obsidian"
      "rectangle"
      "stats"
      "visual-studio-code"
    ];
  };
}
