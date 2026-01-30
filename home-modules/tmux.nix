{ config, lib, pkgs, ... }:

let
  cfg = config.apps.tmux;
in
{
  options.apps.tmux = {
    enable = lib.mkEnableOption "tmux";

    leader = lib.mkOption {
      type = lib.types.str;
      default = "C-a";
      example = "C-Space";
      description = ''
        tmux prefix (leader) key.
        This replaces the default C-b.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;

      baseIndex = 1;
      keyMode = "vi";
      mouse = true;
      terminal = "xterm-256color";

      extraConfig = ''
        ##### indexes #####
        setw -g pane-base-index 1

        ##### terminal / input behavior #####
        set -g extended-keys on
        set -sg escape-time 200
        set -g focus-events on
        set-option -sa terminal-features ',xterm-256color:RGB'

        ##### leader #####
        unbind C-b
        set -g prefix ${cfg.leader}
        bind ${cfg.leader} send-prefix

        ##### unbinds #####
        unbind n
        unbind p
        unbind b

        ##### window / pane management #####
        bind c new-window -c "#{pane_current_path}"
        bind '"' split-window -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"

        ##### navigation #####
        bind '[' previous-window
        bind ']' next-window
        bind p last-window
        bind n switch-client -t foreground
        bind b switch-client -t background

        ##### copy mode #####
        bind v copy-mode
        bind -T copy-mode MouseDragEnd1Pane send -X copy-selection-no-clear
        bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection-no-clear
      '';
    };
  };
}
