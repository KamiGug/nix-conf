{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.lazygit;
in {
  options.apps.lazygit = {
    enable = lib.mkEnableOption "lazygit";

    nvimRemote = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use nvr to open files in an existing Neovim instance.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra lazygit settings merged into programs.lazygit.settings.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = true;

      settings =
        lib.recursiveUpdate
        (lib.optionalAttrs cfg.nvimRemote {
          os = {
            editPreset = "nvim-remote";

            edit = ''
              nvr --remote-send '<CR><CMD>q<CR>:e<CMD>lua vim.cmd("e " .. {{filename}})<CR>'
            '';

            open = ''
              nvr --remote-send '<CR><CMD>q<CR><CMD>lua vim.cmd("e " .. {{filename}})<CR>'
            '';

            editAtLine = ''
              nvr --remote-send '<CR><CMD>q<CR><CMD>lua vim.cmd("e " .. {{filename}})<CR><CMD>{{line}}<CR>'
            '';
          };
        })
        cfg.extraSettings;
    };
    programs.zsh.shellAliases = {
      lg = "lazygit";
    };

    programs.bash.shellAliases = {
      lg = "lazygit";
    };
  };
}
