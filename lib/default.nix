{
  pkgs,
  lib,
  ...
}: {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix {inherit lib pkgs;};
  serv = import ./services {inherit lib pkgs;};
  apps = import ./services/apps;
  validate = import ./validators;
}
