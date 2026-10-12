{
  lib,
  pkgs,
  ...
}: let
  # Commands used to open a file in every editor accepted by apps.using.editor.
  # @file@ and @line@ are replaced by mkEditCommands, so callers decide the quoting.
  templates = {
    neovim = {
      file = ''if [ -n "$NVIM" ]; then nvr --remote-silent @file@; else nvim @file@; fi'';
      atLine = ''if [ -n "$NVIM" ]; then nvr --remote-silent +@line@ @file@; else nvim +@line@ @file@; fi'';
    };

    kakoune = {
      file = ''if [ -n "$KAKOUNE_SESSION" ]; then kak -c "$KAKOUNE_SESSION" @file@; else kak @file@; fi'';
      atLine = ''if [ -n "$KAKOUNE_SESSION" ]; then kak -c "$KAKOUNE_SESSION" @file@ @line@; else kak @file@ @line@; fi'';
    };

    helix = {
      file = "hxr --open @file@ || hx @file@";
      atLine = "hxr --open @file@:@line@ || hx @file@:@line@";
    };

    zed = {
      file = "zeditor @file@";
      atLine = "zeditor @file@:@line@";
    };
  };

  substitute = placeholders:
    lib.replaceStrings
    ["@file@" "@line@"]
    [placeholders.file placeholders.line];

  # All servers referenced by a selection (`myLib.lsp.mkServers`), keyed by id.
  allServers = selected:
    lib.mergeAttrsList (
      lib.mapAttrsToList (_: lang: lang.servers) selected.langs ++ [selected.globals]
    );

  # Editor specific context passed to `myLib.program.mk`, built from a selection.
  contexts = {
    helix = selected: let
      languageServersFor = lang:
        lib.mapAttrsToList (id: _: id) lang.servers ++ lib.attrNames selected.globals;

      languages = lib.concatLists (
        lib.mapAttrsToList (
          _: lang:
            map
            (name: {
              inherit name;
              inherit (lang) roots;
              servers = languageServersFor lang;
            })
            lang.editors.helix
        )
        selected.langs
      );

      servers =
        lib.mapAttrsToList (
          id: server:
            {
              inherit id;
              bin = "${server.package}/bin/${server.command}";
            }
            // lib.optionalAttrs (server.args != []) {inherit (server) args;}
            // lib.optionalAttrs (server ? initializationOptions) {
              config = server.initializationOptions;
            }
        )
        (allServers selected);
    in {
      inherit languages servers;
    };

    kakoune = selected: let
      toKakServer = _: server:
        {
          inherit (server) command;
        }
        // lib.optionalAttrs (server.args != []) {inherit (server) args;};

      languages =
        lib.mapAttrsToList (
          _: lang: {
            pattern = lib.concatStringsSep "|" lang.filetypes;
            inherit (lang) roots;
            servers =
              lib.mapAttrsToList toKakServer lang.servers
              ++ lib.mapAttrsToList toKakServer selected.globals;
          }
        )
        selected.langs;

      filetypes = lib.concatStringsSep "|" (
        lib.unique (
          lib.concatLists (
            lib.mapAttrsToList (_: lang: lang.filetypes) selected.langs
          )
        )
      );
    in {
      lsp = {inherit languages filetypes;};
    };

    zed = selected: let
      langs = lib.filterAttrs (_: lang: lang.editors.zed != null) selected.langs;

      languageServersFor = lang:
        lib.mapAttrsToList (id: _: id) lang.servers ++ lib.attrNames selected.globals;

      zedLanguages =
        lib.foldl' (
          acc: lang:
            acc
            // lib.genAttrs lang.editors.zed (_: {language_servers = languageServersFor lang;})
        )
        {}
        (lib.attrValues langs);

      languages =
        zedLanguages
        // lib.optionalAttrs (langs ? nix) {
          "Nix" =
            (zedLanguages."Nix" or {})
            // {
              formatter.external = {
                command = lib.getExe pkgs.alejandra;
                arguments = ["-"];
              };
            };
        };

      lsp =
        lib.mapAttrs (
          _: server:
            {
              binary =
                {
                  path = "${server.package}/bin/${server.command}";
                }
                // lib.optionalAttrs (server.args != []) {arguments = server.args;};
            }
            // lib.optionalAttrs (server ? initializationOptions) {
              initialization_options = server.initializationOptions;
            }
        )
        (allServers (selected // {inherit langs;}));
    in {
      inherit lsp languages;
    };
  };
in {
  # Legal values for apps.using.editor.
  supportedEditors = builtins.attrNames templates;

  # Commands for the given editor, with @file@/@line@ replaced by the placeholders.
  # Quote the placeholders yourself: ''"{{filename}}"'' for lazygit, "%s" for yazi.
  mkEditCommands = placeholders: editor: let
    args = {line = placeholders.file;} // placeholders;
    template = templates.${editor};
  in
    lib.mapAttrs (_name: command: substitute args command) template;

  # Editor specific context for `myLib.program.mk`.
  mkContext = {
    editor,
    selected,
  }:
    contexts.${editor} selected;

  # Packages of every language server selected for `editor`
  # (editor = null keeps every language, e.g. editors without a per-language view).
  mkLspPackages = {
    editor ? null,
    selected,
  }: let
    langs =
      if editor == null
      then selected.langs
      else lib.filterAttrs (_: lang: (lang.editors.${editor} or null) != null) selected.langs;
  in
    lib.mapAttrsToList (_: server: server.package) (allServers (selected // {inherit langs;}));
}
