args:
let
  parsedArgs = args // {lib = args.pkgs.lib;};
in
{
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix parsedArgs;
  file = import ./file parsedArgs;
  serv = import ./services parsedArgs;
  apps = import ./services/apps parsedArgs;
  validate = import ./validators;
}
