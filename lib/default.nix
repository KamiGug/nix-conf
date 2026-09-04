{ ...} @ args: {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix args;
  mkMutableFile = import ./mkMutableFile.nix;
  ensureDirExists = import ./ensureDirExists.nix;
  serv = import ./services args;
  apps = import ./services/apps args;
  validate = import ./validators;
}
