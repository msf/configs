{ ... }:

# macOS preferences. Security settings (FileVault, SIP, Gatekeeper,
# quarantine, updates) are deliberately not touched here.
# Settings in protected domains (Reduce Transparency/Motion, Increase
# Contrast, analytics) are in ../manual-steps.md.
{
  # Caps Lock -> Control, as on Linux (caps:ctrl).
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      # keyboard
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      ApplePressAndHoldEnabled = false;
      AppleKeyboardUIMode = 3; # Tab moves through all controls

      # no text "help"
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;

      # less animation
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowResizeTime = 0.001;
      NSScrollAnimationEnabled = false;

      # Ctrl+Cmd+drag moves a window from anywhere in it
      NSWindowShouldDragOnGesture = true;

      # dialogs and files
      AppleShowAllExtensions = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;

      "com.apple.sound.beep.feedback" = 0;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      tilesize = 40;
      show-recents = false;
      launchanim = false;
      mineffect = "scale";
      minimize-to-application = true;
      expose-animation-duration = 0.1;
      # keep Spaces in a fixed order
      mru-spaces = false;
      expose-group-apps = true;
      # hot corners off
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
      persistent-apps = [
        "/Applications/Ghostty.app"
        "/Applications/Firefox.app"
        "/Applications/Google Chrome.app"
      ];
      persistent-others = [ ];
    };

    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      FXDefaultSearchScope = "SCcf"; # search the current folder
      FXEnableExtensionChangeWarning = false;
      NewWindowTarget = "Home";
      CreateDesktop = false; # no desktop icons
    };

    WindowManager = {
      GloballyEnabled = false; # Stage Manager
      EnableStandardClickToShowDesktop = false;
      # native tiling duplicates Rectangle
      EnableTilingByEdgeDrag = false;
      EnableTopTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      EnableTiledWindowMargins = false;
    };

    screencapture = {
      # Shift+Cmd+3/4 copy to the clipboard; add Ctrl to save a file instead.
      target = "clipboard";
      location = "/Users/miguel/Pictures";
      type = "png";
      disable-shadow = true;
    };

    controlcenter.BatteryShowPercentage = true;
    loginwindow.GuestEnabled = false;

    CustomUserPreferences = {
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        allowIdentifierForAdvertising = false;
      };
      "com.apple.assistant.support"."Assistant Enabled" = false;
      "com.apple.Siri" = {
        StatusMenuVisible = false;
        VoiceTriggerUserEnabled = false;
      };
      "com.apple.lookup.shared".LookupSuggestionsDisabled = true;
      "com.knollsoft.Rectangle" = {
        launchOnLogin = true;
        gapSize = 5;
      };
      # Photos does not open when a device is plugged in
      "com.apple.ImageCapture".disableHotPlug = true;
    };
  };
}
