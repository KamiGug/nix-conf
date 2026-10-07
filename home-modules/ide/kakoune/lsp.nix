{
  config,
  lib,
  pkgs,
  ...
}: let
  servers = {
    rust = {
      package = pkgs.rust-analyzer;
      name = "rust-analyzer";
      args = [];
      filetypes = ["rust"];
      root_globs = [
        "Cargo.toml"
        "Cargo.lock"
        ".git"
      ];
    };

    nix = {
      package = pkgs.nil;
      name = "nil";
      args = [];
      filetypes = ["nix"];
      root_globs = [
        "flake.nix"
        "flake.lock"
        ".git"
      ];
    };

    typescript = {
      package = pkgs.typescript-language-server;
      name = "typescript-language-server";
      args = ["--stdio"];
      filetypes = [
        "typescript"
        "javascript"
        "typescriptreact"
        "javascriptreact"
      ];
      root_globs = [
        "package.json"
        "tsconfig.json"
        "jsconfig.json"
        ".git"
      ];
    };

    json = {
      package = pkgs.vscode-langservers-extracted;
      name = "vscode-json-language-server";
      args = ["--stdio"];
      filetypes = ["json"];
      root_globs = [
        "package.json"
        ".git"
      ];
    };

    yaml = {
      package = pkgs.yaml-language-server;
      name = "yaml-language-server";
      args = ["--stdio"];
      filetypes = ["yaml"];
      root_globs = [".git"];
    };

    toml = {
      package = pkgs.taplo;
      name = "taplo";
      args = [
        "lsp"
        "stdio"
      ];
      filetypes = ["toml"];
      root_globs = [
        "Cargo.toml"
        "pyproject.toml"
        ".git"
      ];
    };

    bash = {
      package = pkgs.bash-language-server;
      name = "bash-language-server";
      args = ["start"];
      filetypes = [
        "bash"
        "sh"
      ];
      root_globs = [".git"];
    };

    fish = {
      package = pkgs.fish-lsp;
      name = "fish-lsp";
      args = ["start"];
      filetypes = ["fish"];
      root_globs = [
        "config.fish"
        ".git"
      ];
    };

    elvish = {
      package = pkgs.elvish;
      name = "elvish";
      args = ["-lsp"];
      filetypes = ["elvish"];
      root_globs = [".git"];
    };

    go = {
      package = pkgs.gopls;
      name = "gopls";
      args = [];
      filetypes = ["go"];
      root_globs = [
        "go.mod"
        "go.work"
        ".git"
      ];
    };

    c = {
      package = pkgs.clang-tools;
      name = "clangd";
      args = [];
      filetypes = [
        "c"
        "cpp"
        "objc"
        "objcpp"
      ];
      root_globs = [
        "compile_commands.json"
        "compile_flags.txt"
        ".clangd"
        ".git"
      ];
    };

    python = {
      package = pkgs.pyright;
      name = "pyright-langserver";
      args = ["--stdio"];
      filetypes = ["python"];
      root_globs = [
        "pyproject.toml"
        "setup.py"
        "setup.cfg"
        ".git"
      ];
    };

    csharp = {
      package = pkgs.roslyn-ls;
      name = "Microsoft.CodeAnalysis.LanguageServer";
      args = ["--stdio"];
      filetypes = ["csharp"];
      root_globs = [
        "*.sln"
        "*.csproj"
        ".git"
      ];
    };
  };

  filetypes = lib.concatStringsSep "|" (
    lib.unique (
      lib.concatLists (
        lib.mapAttrsToList (
          _: server: server.filetypes
        )
        servers
      )
    )
  );

  packages =
    lib.mapAttrsToList (
      _: server: server.package
    )
    servers;

  mkServerBlock = name: server: ''
    hook global BufSetOption filetype=(${lib.concatStringsSep "|" server.filetypes}) %{
      set-option buffer lsp_servers %{
        [${server.name}]
        ${lib.optionalString (server.args != []) "args = ${builtins.toJSON server.args}"}
        root_globs = ${builtins.toJSON server.root_globs}
      }
    }
  '';

  serverHooks = lib.concatStringsSep "\n\n" (lib.mapAttrsToList mkServerBlock servers);
in {
  nix = {
    home.packages =
      packages
      ++ [
        pkgs.kakoune-lsp
      ];
  };

  kakoune = ''
    # ─────────────────────────────────────────────────────────────
    # LSP
    # ─────────────────────────────────────────────────────────────

    eval %sh{kak-lsp}

    ${serverHooks}

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
    map global code l ':enter-user-mode lsp<ret>' \
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
