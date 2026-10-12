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
    "org.hammerspoon.Hammerspoon" = {
      MJConfigFile = "~/.config/hammerspoon/init.lua";
    };
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
