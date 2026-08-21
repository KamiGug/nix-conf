{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.nvim;
in {
  options.apps.nvim = {
    enable = lib.mkEnableOption "Neovim (native, nix-ld based)";
  };

  config = lib.mkIf cfg.enable {
    # Native Neovim (no wrapper)
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    # Your config repo
    xdg.configFile."nvim".source = pkgs.fetchFromGitHub {
      owner = "KamiGug";
      repo = "nvim-config";
      rev = "HEAD";
      sha256 = "sha256-4yoOqpxYrycyAtQmVfkmaVdPNMba/z9Y5qRisbNs6SY=";
    };
    home.packages = with pkgs; [
      git
      lazygit
      ripgrep
      fd
      tree-sitter
      wget
      unzip

      gcc
      gnumake
      cmake
      pkg-config

      nodejs_20
      python3
      cargo
      rustc
      luajit

      ast-grep
      ghostscript
      tectonic
      nodePackages.mermaid-cli
    ];
  };
}
