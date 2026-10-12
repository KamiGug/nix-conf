{
  config,
  lib,
  ...
}: let
  editors = ["helix" "kakoune" "nvim" "zed"];

  defaults =
    lib.filter
    (id: config.apps.${id}.enable && config.apps.${id}.defaultEditor)
    editors;
in {
  assertions = [
    {
      assertion = lib.length defaults <= 1;
      message = "Only one default editor can be active, disable apps.helix.defaultEditor, apps.kakoune.defaultEditor, apps.nvim.defaultEditor or apps.zed.defaultEditor.";
    }
  ];
}
