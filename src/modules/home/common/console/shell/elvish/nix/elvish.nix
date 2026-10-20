{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.elvish;
in {
  home.sessionPath = [
    "$HOME/.local/share/scripts"
  ];

  home.file = {
    ".config/elvish/rc.elv" = {
      text = ''
        use re
        use direnv

        if (or (has-env SSH_CLIENT) (has-env SSH_TTY)) {
          set-env IS_SSH_HOST true
        }

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

        ${lib.optionalString cfg.zellijAutostart ''
          if (and (not (has-env IS_SSH_HOST)) (not (has-env ZELLIJ)) (not (has-env TMUX)) (has-external zellij)) {
            exec zellij
          }
        ''}
      '';
      executable = true;
    };
    ".config/elvish/lib/direnv.elv".source = pkgs.writeText "direnv.elv" ''
      ${builtins.readFile (
        pkgs.runCommand "direnv-hook" {} ''
          ${pkgs.direnv}/bin/direnv hook elvish > $out
        ''
      )}
    '';
  };
}
