{
  config,
  lib,
  # pkgs,
  ...
}: let
  cfg = config.apps.starship;
in {
  options.apps.starship = {
    enable = lib.mkEnableOption "Starship prompt configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      # enableFishIntegration = true;

      settings = {
        add_newline = true;

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };

        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
          style = "bold cyan";
        };

        git_branch = {
          symbol = "🌱 ";
          style = "bold purple";
          truncation_length = 20;
        };

        git_status = {
          conflicted = "🏳";
          ahead = "🏎💨";
          behind = "😰";
          diverged = "😵";
          untracked = "🤷";
          stashed = "📦";
          modified = "📝";
          staged = "[++\\($count\\)](green)";
          renamed = "👅";
          deleted = "🗑";
        };

        cmd_duration = {
          min_time = 500;
          format = "[$duration]($style) ";
        };

        nix_shell = {
          symbol = "❄️ ";
          format = "via [$symbol$state( \\($name\\))]($style) ";
        };
      };
    };
  };
}
