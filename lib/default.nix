{
  pkgs,
  lib,
  ...
}: {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix {inherit pkgs;};
  serv = import ./services {inherit lib pkgs;};
  apps = import ./services/apps;
  validate = import ./validators;
}
