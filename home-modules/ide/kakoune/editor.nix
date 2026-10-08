{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    programs.kakoune = {
      enable = true;
      defaultEditor = config.apps.kakoune.defaultEditor;

      config = {
        numberLines = {
          enable = true;
          relative = true;
        };

        scrollOff = {
          lines = 5;
          columns = 5;
        };

        autoComplete = [
          "insert"
          "prompt"
        ];

        autoInfo = [
          "command"
          "onkey"
          "normal"
        ];
      };
    };
  };

  kakoune = "";
}
