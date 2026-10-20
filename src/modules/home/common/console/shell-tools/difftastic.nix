{
  config,
  lib,
  ...
}: let
  cfg = config.apps.difftastic;
in {
  options.apps.difftastic = {
    enable = lib.mkEnableOption "difftastic, a structural diff tool";

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        CONTEXT = "10";
        COLOR = "always";
      };
      description = ''
        Difftastic has no config file, every option is read from the command
        line or from a DFT_ environment variable. Values here are exported
        as DFT_<name>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.difftastic.enable = true;

    home.sessionVariables = lib.mapAttrs' (name: value:
      lib.nameValuePair "DFT_${name}" value)
    cfg.env;
  };
}
