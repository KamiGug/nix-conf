{lib, ...}: let
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
}
