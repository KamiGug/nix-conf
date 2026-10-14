{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.lazygit;

  edit =
    myLib.editor.mkEditCommands {
      file = ''"{{filename}}"'';
      line = ''"{{line}}"'';
    }
    config.apps.using.editor;
in {
  options.apps.lazygit = {
    enable = lib.mkEnableOption "lazygit";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      apps.difftastic.enable = lib.mkDefault true;
      apps.gitDelta.enable = lib.mkDefault true;
    }

    (myLib.program.mk {
      dir = ./.;
      target = "lazygit";
      force = true;
      args = {inherit config lib myLib;};
      context = {
        inherit (edit) file atLine;
        diffContext = "{{diffContext}}";
        difftastic = config.apps.difftastic.enable;
        gitDelta = config.apps.gitDelta.enable;
        opencode = config.apps.opencode.enable;
      };
    })
  ]);
}
