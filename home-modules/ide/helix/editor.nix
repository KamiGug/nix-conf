{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    programs.helix = {
      enable = true;
    };
  };

  helix = {
    editor = {
      line-number = "relative";
      cursorline = true;
      color-modes = true;
      scrolloff = 5;
      auto-completion = true;
      auto-pairs = true;
      indent-guides = {
        render = true;
      };

      lsp = {
        auto-format = true;
        display-messages = true;
      };
    };
  };
}
