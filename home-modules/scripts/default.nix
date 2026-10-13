{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeModules.rustCrates;
  dir = ./rust;
  entries = builtins.readDir dir;
  crates =
    builtins.filter
    (name: {
      isDir = builtins.pathExists (dir + "/" + name + "/.");
      hasCargo = builtins.pathExists (dir + "/" + name + "/cargo.toml");
    }).name;
in {
  options.homeModules.rustCrates = {
    enable = lib.mkEnableOption "Enable rust crate derivations";
  };

  config = lib.mkIf cfg.enable {
    home.bin =
      lib.mapAttrs (
        name: _: let
          cratePath = dir + "/" + name;
          cargo = cratePath + "/cargo.toml";
        in
          if builtins.pathExists cargo
          then (pkgs.cargoBuild.tryImport cratePath // {name = name;})
          else null
      )
      crates;
  };
}
