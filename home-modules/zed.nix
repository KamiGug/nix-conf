{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.zed;

  lspBinaries = {
    clangd = pkgs.clang-tools;
    csharp = pkgs.csharp-ls;
    rust = pkgs.rust-analyzer;
    cmake = pkgs.cmake-language-server;
    yaml = pkgs.yaml-language-server;
    typos = pkgs.typos;
    nix = pkgs.nixd;
    nixFormatter = pkgs.alejandra;
  };
in {
  options.apps.zed.enable = lib.mkEnableOption "Zed Editor (LSP + Vim motions + Typos)";

  config = lib.mkIf cfg.enable {
    programs.zed-editor.enable = true;
    programs.zed-editor.extensions = ["nix" "toml"];

    programs.zed-editor.userSettings = {
      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 13.5;
      format_on_save = "off";

      terminal = {
        shell = "system";
        working_directory = "current_project_directory";
      };

      lsp = {
        clangd = {binary = {path = "${lspBinaries.clangd}/bin/clangd";};};
        csharp-ls = {binary = {path = lib.getExe lspBinaries.csharp;};};
        rust-analyzer = {binary = {path = lib.getExe lspBinaries.rust;};};
        cmake-language-server = {binary = {path = lib.getExe lspBinaries.cmake;};};
        yaml-language-server = {
          binary = {
            path = lib.getExe lspBinaries.yaml;
            arguments = ["--stdio"];
          };
        };
        nixd = {binary = {path = lib.getExe lspBinaries.nix;};};

        typos = {
          binary = {path = lib.getExe lspBinaries.typos;};
          initialization_options = {
            config_path = "./typos.toml";
            diagnostic_severity = "Warning";
          };
        };
      };

      languages = {
        "Rust" = {language_servers = ["rust-analyzer" "typos"];};
        "C" = {language_servers = ["clangd" "typos"];};
        "C++" = {language_servers = ["clangd" "typos"];};
        "C#" = {language_servers = ["csharp-ls" "typos"];};
        "YAML" = {language_servers = ["yaml-language-server" "typos"];};
        "CMake" = {language_servers = ["cmake-language-server" "typos"];};
        "Nix" = {
          language_servers = ["nixd" "typos"];
          formatter = {
            external = {
              command = lib.getExe lspBinaries.nixFormatter;
              arguments = ["-"];
            };
          };
        };
      };
    };

    home.packages = lib.attrValues lspBinaries;
  };
}
