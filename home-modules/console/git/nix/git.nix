{
  config,
  lib,
  ...
}: let
  cfg = config.apps.git;

  delta = lib.getExe config.programs.delta.package;
in {
  apps.difftastic.enable = lib.mkDefault true;
  apps.gitDelta.enable = lib.mkDefault true;
  programs.difftastic.git.enable = lib.mkDefault config.apps.difftastic.enable;

  programs.git = {
    enable = true;
    lfs.enable = true;

    settings =
      {
        user.name = cfg.user.name;
        user.email = cfg.user.email;
        init.defaultBranch = "master";
        core.autocrlf = "input";
        safe = {
          directory = ["/etc/nixos"];
        };
      }
      // lib.optionalAttrs config.apps.gitDelta.enable {
        delta = config.apps.gitDelta.settings;

        pager =
          {
            blame = delta;
            log = delta;
            show = delta;
          }
          # difftastic pages itself through less on `git diff`.
          // lib.optionalAttrs (!config.apps.difftastic.enable) {
            diff = delta;
          };

        interactive.diffFilter = "${delta} --color-only";
      };
  };
}
