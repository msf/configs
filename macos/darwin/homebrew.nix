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

    brews = [
      # GNU timeout etc.; shell PATH already lists opt/coreutils/libexec/gnubin.
      "coreutils"
      "ffmpeg"
      "pgcli"
      "yt-dlp"
    ];

    casks = [
      "1password"
      "1password-cli"
      "discord"
      "gcloud-cli"
      "ghostty"
      "gimp"
      "iina"
      "kitty"
      "localsend"
      "obsidian"
      "rectangle"
      "slack"
      "stats"
      "visual-studio-code"
    ];
  };
}
