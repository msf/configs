{ config, lib, ... }:

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

  # Persist the ID80-only swap in macOS's per-host modifier preferences.
  # USB HID keyboard usages: left Option/Command = 0xE2/0xE3, right = 0xE6/0xE7.
  system.activationScripts.postActivation.text = let
    id80ModifierMapping = [
      { HIDKeyboardModifierMappingSrc = 30064771298; HIDKeyboardModifierMappingDst = 30064771299; }
      { HIDKeyboardModifierMappingSrc = 30064771299; HIDKeyboardModifierMappingDst = 30064771298; }
      { HIDKeyboardModifierMappingSrc = 30064771302; HIDKeyboardModifierMappingDst = 30064771303; }
      { HIDKeyboardModifierMappingSrc = 30064771303; HIDKeyboardModifierMappingDst = 30064771302; }
    ];
    spaceShortcut = character: keyCode: lib.escapeShellArg (lib.generators.toPlist { escape = true; } {
      enabled = true;
      value = {
        type = "standard";
        # NSEvent Control modifier (0x40000); 65535 means no printable character.
        parameters = [ character keyCode 262144 ];
      };
    });
  in ''
    /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} \
      /usr/bin/defaults -currentHost write -g \
      com.apple.keyboard.modifiermapping.26980-128-0 \
      ${lib.escapeShellArg (lib.generators.toPlist { escape = true; } id80ModifierMapping)}

    # Merge Mission Control bindings without replacing unrelated system shortcuts.
    # Symbolic hotkey IDs: 79/81 = left/right; 118–126 = desktops 1–9.
    /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} \
      /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
      79 ${spaceShortcut 65535 123} \
      81 ${spaceShortcut 65535 124} \
      118 ${spaceShortcut 49 18} \
      119 ${spaceShortcut 50 19} \
      120 ${spaceShortcut 51 20} \
      121 ${spaceShortcut 52 21} \
      122 ${spaceShortcut 53 23} \
      123 ${spaceShortcut 54 22} \
      124 ${spaceShortcut 55 26} \
      125 ${spaceShortcut 56 28} \
      126 ${spaceShortcut 57 25}
  '';

  # minutes until the display turns off (battery was 2, AC 10)
  power.sleep.display = 15;

  system.defaults = {
    NSGlobalDomain = {
      # keyboard
      InitialKeyRepeat = 25;
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

    spaces.spans-displays = false;

    controlcenter.BatteryShowPercentage = true;
    controlcenter.Sound = true;
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
        alternateDefaultShortcuts = true;
        # NSEvent Control+Option = 0xC0000; adding Shift = 0xE0000.
        leftHalf = { keyCode = 123; modifierFlags = 786432; };
        rightHalf = { keyCode = 124; modifierFlags = 786432; };
        topHalf = { keyCode = 126; modifierFlags = 786432; };
        bottomHalf = { keyCode = 125; modifierFlags = 786432; };
        maximize = { keyCode = 36; modifierFlags = 786432; };
        firstThird = { keyCode = 18; modifierFlags = 786432; };
        centerThird = { keyCode = 19; modifierFlags = 786432; };
        lastThird = { keyCode = 20; modifierFlags = 786432; };
        firstTwoThirds = { keyCode = 21; modifierFlags = 786432; };
        lastTwoThirds = { keyCode = 23; modifierFlags = 786432; };
        previousDisplay = { keyCode = 123; modifierFlags = 917504; };
        nextDisplay = { keyCode = 124; modifierFlags = 917504; };
      };
      # Photos does not open when a device is plugged in
      "com.apple.ImageCapture".disableHotPlug = true;
    };
  };
}
