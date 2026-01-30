{ config, lib, pkgs, ... }:

let
  cfg = config.apps.zed;

  lspBinaries = {
    clangd                  = pkgs.clang-tools;
    csharp                  = pkgs.csharp-ls;
    rustAnalyzer            = pkgs.rust-analyzer;
    cmakeLS                 = pkgs.cmake-language-server;
    yamlLS                  = pkgs.yaml-language-server;
    typos                   = pkgs.typos;
  };
in
{
  options.apps.zed.enable = lib.mkEnableOption "Zed Editor (LSP + Vim motions + Typos)";

  config = lib.mkIf cfg.enable {
    programs.zed-editor.enable = true;

    programs.zed-editor.extensions = [ "nix" "toml" "yaml" "csharp" "cmake" ];

    programs.zed-editor.userSettings = {
      vim_mode = true;

      terminal = {
        shell = "system";
        working_directory = "current_project_directory";
      };

      lsp = {
        "clangd" = { binary.path = lib.getExe lspBinaries.clangd; };
        "csharp-language-server" = { binary.path = lib.getExe lspBinaries.csharp; };
        "rust-analyzer" = { binary.path = lib.getExe lspBinaries.rustAnalyzer; };
        "cmake-language-server" = { binary.path = lib.getExe lspBinaries.cmakeLS; };
        "yaml-language-server" = { binary.path = lib.getExe lspBinaries.yamlLS; };
        "typos" = {
          binary.path = lib.getExe lspBinaries.typos;
          settings = {
            include = ["**/*.rs" "**/*.c" "**/*.cpp" "**/*.cs" "**/*.py" "**/*.lua"];
          };
        };
      };

      languages = {
        "Rust" = { language_servers = [ "rust-analyzer" ]; };
        "C" = { language_servers = [ "clangd" ]; };
        "C++" = { language_servers = [ "clangd" ]; };
        "C#" = { language_servers = [ "csharp-language-server" ]; };
        "YAML" = { language_servers = [ "yaml-language-server" ]; };
        "CMake" = { language_servers = [ "cmake-language-server" ]; };
      };

      ui_font_size = 16;
      buffer_font_size = 16;
    };

    home.packages = with pkgs; [
      clang-tools
      csharp-ls
      rust-analyzer
      cmake-language-server
      yaml-language-server
      typos
    ];
  };
}

