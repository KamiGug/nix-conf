{
  pkgs,
  ...
}@args: {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix args;
  serv = import ./services args;
  apps = import ./services/apps args;
  validate = import ./validators;
}
