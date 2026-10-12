{
  myLib,
  pkgs,
  selected,
  ...
}: {
  home.packages =
    myLib.editor.mkLspPackages {
      editor = "zed";
      inherit selected;
    }
    ++ [pkgs.alejandra];
}
