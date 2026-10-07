{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.kakoune;

  moduleArgs = {
    inherit config lib pkgs;
  };

  files =
    lib.filterAttrs
    (name: type:
      type
      == "regular"
      && lib.hasSuffix ".nix" name
      && name != "default.nix")
    (builtins.readDir ./.);

  modules =
    map
    (name: (import ./${name}) moduleArgs)
    (lib.attrNames files);

  nixConfig =
    lib.mkMerge (map (module: module.nix) modules);

  kakouneConfig =
    lib.concatStringsSep "\n" (map (module: module.kakoune) modules);
in {
  options.apps.kakoune = {
    enable = lib.mkEnableOption "Kakoune editor";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      nixConfig

      {
        programs.kakoune.extraConfig = kakouneConfig;
      }
    ]
  );
}
