{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.opencode;
  configDir = ./config;
  configFiles =
    lib.mapAttrs'
    (file: _type:
      lib.nameValuePair "opencode/${file}" {
        source = configDir + "/${file}";
      })
    (builtins.readDir configDir);
in {
  options.apps.opencode.enable =
    lib.mkEnableOption "OpenCode AI coding agent";

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.opencode];

    xdg.configFile = configFiles;
  };
}
