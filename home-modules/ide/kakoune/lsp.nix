{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  selected = myLib.lsp.mkServers {
    blacklist = [
      "typos"
      "nix/nixd"
      "nix/tix"
      "csharp/csharp-ls"
    ];
  };

  inherit (selected) langs;

  filetypes = lib.concatStringsSep "|" (
    lib.unique (
      lib.concatLists (
        lib.mapAttrsToList (
          _: lang: lang.filetypes
        )
        langs
      )
    )
  );

  packages = lib.concatLists (
    lib.mapAttrsToList (
      _: lang: lib.mapAttrsToList (_: server: server.package) lang.servers
    )
    langs
  );

  mkServerSections = lang:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        _: server: ''
          [${server.command}]
          ${lib.optionalString (server.args != []) "args = ${builtins.toJSON server.args}"}
          root_globs = ${builtins.toJSON lang.roots}
        ''
      )
      lang.servers
    );

  mkServerBlock = _: lang: ''
    hook global BufSetOption filetype=(${lib.concatStringsSep "|" lang.filetypes}) %{
      set-option buffer lsp_servers %{
        ${mkServerSections lang}
      }
    }
  '';

  serverHooks = lib.concatStringsSep "\n\n" (lib.mapAttrsToList mkServerBlock langs);
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
