#TODO: starship, elvish-bash-completion, carapace, atuin (+ add to ctrl + R). yazi, fzf, fd, rg, direnv

{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.elvish;
in {
  options.apps.elvish = {
    enable = lib.mkEnableOption "Elvish configuration";

    tmuxAutostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically enter tmux on shell startup.";
    };

    starshipEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable starship";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.sessionPath = [
        "$HOME/.local/share/scripts"
      ];

      home.packages = with pkgs; [
        elvish
        direnv
        # carapace # make a module
        # atuin # make a module
      ];

      apps.my.scripts.enable = true;

      home.file = {
        ".config/elvish/rc.elv" = {
          text = ''
            use re
            use direnv
            # if set -q SSH_CLIENT; or set -q SSH_TTY
            #   set -gx IS_SSH_HOST true
            # end

            # set -gx FOREGROUND_SESSION_NAME foreground
            # set -gx BACKGROUND_SESSION_NAME background

            ${lib.optionalString cfg.starshipEnabled "eval (starship init elvish)"}


            # if command -q tmux
            #   alias etf="enter-tmux-session $FOREGROUND_SESSION_NAME"
            #   alias etb="enter-tmux-session $BACKGROUND_SESSION_NAME"
            #   alias ets="enter-tmux-session"
            #   alias ats="add-to-tmux-session"
            #   alias atb="add-to-tmux-session --session $BACKGROUND_SESSION_NAME --cmd"
            # end
          '';
          executable = true;
        };
        ".config/elvish/lib/direnv".source =
            lib.getExe pkgs.runCommand "direnv-elvish-hook" {} ''
              mkdir -p $out
              ${pkgs.direnv}/bin/direnv hook elvish > $out/direnv.elv
            '';
      };
    }
    (lib.mkIf cfg.starshipEnabled {
      apps.starship.enable = true;
    })
  ]);
}
