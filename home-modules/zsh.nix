{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.zsh;
in {
  options.apps.zsh = {
    enable = lib.mkEnableOption "user shell environment (zsh + tmux helpers)";

    tmuxAutostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically enter tmux on shell startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionPath = [
      "$HOME/.local/share/scripts"
    ];

    programs.zsh = {
      enable = true;

      oh-my-zsh = {
        enable = true;
        theme = "aussiegeek";
        plugins = ["git" "git-lfs" "tmux"];
      };

      shellAliases = {
        nvim-conf = "cd ~/.config/nvim && nvim .";
      };

      initContent = ''
             if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
               export IS_SSH_HOST=true
             fi

             export FOREGROUND_SESSION_NAME=foreground
             export BACKGROUND_SESSION_NAME=background

             if command -v tmux >/dev/null 2>&1; then
               alias etf="enter-tmux-session $FOREGROUND_SESSION_NAME"
               alias etb="enter-tmux-session $BACKGROUND_SESSION_NAME"
               alias ets="enter-tmux-session"
               alias ats="add-to-tmux-session"
               alias atb="add-to-tmux-session --session $BACKGROUND_SESSION_NAME --cmd "
             fi

             ${lib.optionalString cfg.tmuxAutostart ''
          if [[ -z "$IS_SSH_HOST" && -z "$TMUX" ]]; then
            enter-tmux-session "$FOREGROUND_SESSION_NAME"
          fi
        ''}

             nvim() {
               local repo_name
               if git config --get remote.origin.url >/dev/null 2>&1; then
                 repo_name=$(basename -s .git "$(git config --get remote.origin.url)")
               else
                 repo_name=$(basename "$(pwd)")
               fi
        if [ -z "$TMUX" ]; then
               	tmux rename-window "$repo_name"
        fi
               command nvim "$@"
             }
      '';
    };

    home.file.".local/share/scripts" = {
      source = ../home-scripts;
      recursive = true;
    };
  };
}
