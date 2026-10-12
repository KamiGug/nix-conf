{
  myLib,
  pkgs,
  selected,
  ...
}: {
  home.packages =
    myLib.editor.mkLspPackages {inherit selected;}
    ++ [pkgs.kakoune-lsp];
}
