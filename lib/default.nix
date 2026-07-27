{
  pkgs,
  ...
}@args: {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix args;
  mkMutableFile = import ./mkMutableFile.nix;
  serv = import ./services args;
  validate = import ./validators;
}
