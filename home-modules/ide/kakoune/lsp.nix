{ config, lib, pkgs, ... }:

let
  servers = {
    rust = {
      package = pkgs.rust-analyzer;
      command = "rust-analyzer";
      filetypes = [ "rust" ];
      roots = [
        "Cargo.toml"
        "Cargo.lock"
        ".git"
      ];
    };

    nix = {
      package = pkgs.nil;
      command = "nil";
      filetypes = [ "nix" ];
      roots = [
        "flake.nix"
        "flake.lock"
        ".git"
      ];
    };

    typescript = {
      package = pkgs.typescript-language-server;
      command = "typescript-language-server";
      args = [ "--stdio" ];
      filetypes = [
        "typescript"
        "javascript"
        "typescriptreact"
        "javascriptreact"
      ];
      roots = [
        "package.json"
        "tsconfig.json"
        "jsconfig.json"
        ".git"
      ];
    };

    json = {
      package = pkgs.vscode-langservers-extracted;
      command = "vscode-json-language-server";
      args = [ "--stdio" ];
      filetypes = [ "json" ];
      roots = [
        "package.json"
        ".git"
      ];
    };

    yaml = {
      package = pkgs.yaml-language-server;
      command = "yaml-language-server";
      args = [ "--stdio" ];
      filetypes = [ "yaml" ];
      roots = [ ".git" ];
    };

    toml = {
      package = pkgs.taplo;
      command = "taplo";
      args = [
        "lsp"
        "stdio"
      ];
      filetypes = [ "toml" ];
      roots = [
        "Cargo.toml"
        "pyproject.toml"
        ".git"
      ];
    };

    bash = {
      package = pkgs.bash-language-server;
      command = "bash-language-server";
      args = [ "start" ];
      filetypes = [
        "bash"
        "sh"
      ];
      roots = [ ".git" ];
    };

    fish = {
      package = pkgs.fish-lsp;
      command = "fish-lsp";
      args = [ "start" ];
      filetypes = [ "fish" ];
      roots = [
        "config.fish"
        ".git"
      ];
    };

    elvish = {
      package = pkgs.elvish;
      command = "elvish";
      args = [ "-lsp" ];
      filetypes = [ "elvish" ];
      roots = [ ".git" ];
    };

    go = {
      package = pkgs.gopls;
      command = "gopls";
      filetypes = [ "go" ];
      roots = [
        "go.mod"
        "go.work"
        ".git"
      ];
    };

    c = {
      package = pkgs.clang-tools;
      command = "clangd";
      filetypes = [
        "c"
        "cpp"
        "objc"
        "objcpp"
      ];
      roots = [
        "compile_commands.json"
        "compile_flags.txt"
        ".clangd"
        ".git"
      ];
    };

    python = {
      package = pkgs.pyright;
      command = "pyright-langserver";
      args = [ "--stdio" ];
      filetypes = [ "python" ];
      roots = [
        "pyproject.toml"
        "setup.py"
        "setup.cfg"
        "requirements.txt"
        ".git"
      ];
    };

    csharp = {
      package = pkgs.roslyn-ls;
      command = "Microsoft.CodeAnalysis.LanguageServer";
      args = [ "--stdio" ];
      filetypes = [ "csharp" ];
      roots = [
        "*.sln"
        "*.csproj"
        ".git"
      ];
    };
  };

  toml = pkgs.formats.toml { };

  kakLspConfig = toml.generate "kak-lsp.toml" {
    language = lib.mapAttrs (
      _: server: {
        filetypes = server.filetypes;
        roots = server.roots;
        command = server.command;
        args = server.args or [ ];
      }
    ) servers;
  };

  filetypes =
    lib.concatStringsSep "|" (
      lib.unique (
        lib.concatLists (
          lib.mapAttrsToList (
            _: server: server.filetypes
          ) servers
        )
      )
    );

  packages =
    lib.mapAttrsToList (
      _: server: server.package
    ) servers;
in
{
  nix = {
    home.packages = packages ++ [
      pkgs.kakoune-lsp
    ];

    xdg.configFile."kak-lsp/kak-lsp.toml".source =
      kakLspConfig;
  };

  kakoune = ''
    # ─────────────────────────────────────────────────────────────
    # LSP
    # ─────────────────────────────────────────────────────────────

    eval %sh{kak-lsp --kakoune -s $kak_session}

    # Automatically enable LSP for configured filetypes.
    hook global WinSetOption filetype=(${filetypes}) %{
      lsp-enable-window
    }

    # Format on save.
    hook global BufWritePre .* %{
      lsp-formatting-sync
    }

    # LSP status.
    set-option global modelinefmt "%opt{lsp_modeline} %opt{modelinefmt}"

    # LSP mode.
    map global user l ':enter-user-mode lsp<ret>' \
      -docstring 'LSP mode'

    # Navigation.
    map global goto d '<esc>:lsp-definition<ret>' \
      -docstring 'LSP definition'

    map global goto r '<esc>:lsp-references<ret>' \
      -docstring 'LSP references'

    map global goto y '<esc>:lsp-type-definition<ret>' \
      -docstring 'LSP type definition'
  '';
}
