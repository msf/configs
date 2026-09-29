{ ... }:

# GUI applications through the existing /opt/homebrew installation.
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

    casks = [
      "ghostty"
      "kitty"
      "visual-studio-code"
      "discord"
      "rectangle"
    ];
  };
}
