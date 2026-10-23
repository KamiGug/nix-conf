{
  # config,
  lib,
  myLib,
  # pkgs,
  ...
}: {
  options.apps.using = {
    terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = "zsh";
    };

    terminalFont = lib.mkOption {
      type = lib.types.str;
      default = "GeistMono Nerd Font";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    editor = lib.mkOption {
      type = lib.types.enum myLib.editor.supportedEditors;
      default = "neovim";
      description = "Editor used by tools that open files on your behalf, like lazygit and yazi.";
    };
  };
}
