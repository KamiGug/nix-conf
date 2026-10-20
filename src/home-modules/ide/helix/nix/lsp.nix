{
  myLib,
  selected,
  ...
}: {
  home.packages = myLib.editor.mkLspPackages {inherit selected;};
}
