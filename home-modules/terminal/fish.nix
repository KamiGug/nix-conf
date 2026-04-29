{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.fish;
in {
  options.apps.fish = {
    enable = lib.mkEnableOption "Fish configuration";

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
        direnv
      ];

      programs.fish = {
        enable = true;
        interactiveShellInit = ''
          if set -q SSH_CLIENT; or set -q SSH_TTY
            set -gx IS_SSH_HOST true
          end

          set -gx FOREGROUND_SESSION_NAME foreground
          set -gx BACKGROUND_SESSION_NAME background

          ${lib.optionalString cfg.starshipEnabled "starship init fish | source"}

          direnv hook fish | source

          if command -q tmux
            alias etf="enter-tmux-session $FOREGROUND_SESSION_NAME"
            alias etb="enter-tmux-session $BACKGROUND_SESSION_NAME"
            alias ets="enter-tmux-session"
            alias ats="add-to-tmux-session"
            alias atb="add-to-tmux-session --session $BACKGROUND_SESSION_NAME --cmd"
          end

          ${lib.optionalString cfg.tmuxAutostart ''
            if not set -q IS_SSH_HOST; and not set -q TMUX
              exec tmux
            end
          ''}

          function nvim
            set repo_name ""

            if git config --get remote.origin.url >/dev/null 2>&1
              set repo_name (basename (string replace -r '\.git$' "" (git config --get remote.origin.url)))
            else
              set repo_name (basename (pwd))
            end

            if not set -q TMUX
              tmux rename-window "$repo_name"
            end

            command nvim $argv
          end
        '';

        shellAbbrs = {};
      };

      home.file.".local/share/scripts" = {
        source = ../../home-scripts;
        recursive = true;
      };
    }
    (lib.mkIf cfg.starshipEnabled {
      apps.starship.enable = true;
    })
  ]);
}
