{
  # pkgs,
  # config,
  # inputs,
  ...
}: {
  nixpkgs.config.allowUnfree = true;
  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = true;
    };

    casks = [
      "karabiner-elements"
      "hammerspoon"
    ];

    brews = [
      # "paneru"
    ];
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.HIToolbox" = {
      AppleEnabledInputSources = [
        {
          InputSourceKind = "Keyboard Layout";
          "KeyboardLayout Name" = "Polish";
        }
      ];
    };
  };
}
