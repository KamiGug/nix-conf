{
  pkgs,
  lib,
  ...
}@args: {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix {inherit pkgs;};
  serv = import ./services args;
  apps = import ./services/apps args;
  validate = import ./validators;
}
