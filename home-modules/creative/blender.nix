{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.apps.blender;

  blenderPkg = pkgs.blender;

  version = let
    v = lib.getVersion blenderPkg;
    parts = lib.splitString "." v;
  in
    lib.concatStringsSep "." (lib.take 2 parts);

  addons = with pkgs.blenderAddons or {}; [
    # example:
    # node-wrangler
    # my-addon
  ];

  addonFiles = map (
    addon: let
      name =
        addon.pname or
          (builtins.parseDrvName addon.name).name;
    in
      nameValuePair
      ".config/blender/${version}/scripts/addons/${name}"
      {source = addon;}
  )
  addons;
in {
  options.apps.blender = {
    enable = mkEnableOption "Blender";
  };

  config = mkIf cfg.enable {
    home.packages = [blenderPkg];

    home.file = builtins.listToAttrs addonFiles;
  };
}
