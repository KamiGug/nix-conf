{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.my.scripts;
  rustDir = ./rust;
  crateNames =
    if builtins.pathExists rustDir
    then
      builtins.filter
      (name: builtins.pathExists (rustDir + "/${name}/Cargo.toml"))
      (builtins.attrNames (builtins.readDir rustDir))
    else [];

  mkCrate = name:
    pkgs.rustPlatform.buildRustPackage {
      pname = name;
      version = "0.1.0";

      src = lib.cleanSource (rustDir + "/${name}");
      cargoLock.lockFile = rustDir + "/${name}/Cargo.lock";

      meta = {
        mainProgram = name;
      };
    };
in {
  options.apps.my.scripts = {
    enable = lib.mkEnableOption "Enable home scripts";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.jq] ++ map mkCrate crateNames;

    home.sessionPath = [
      "$HOME/.local/share/scripts"
    ];

    home.file = {
      ".local/share/scripts" = {
        source = ./bash;
        recursive = true;
        executable = true;
      };
    };
  };
}
