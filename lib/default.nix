args: let
  parsedArgs = args // {lib = args.pkgs.lib;};
in {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix parsedArgs;
  editor = import ./editor.nix parsedArgs;
  lsp = import ./lsp.nix parsedArgs;
  file = import ./file parsedArgs;
  serv = import ./services parsedArgs;
  apps = import ./services/apps parsedArgs;
  validate = import ./validators;
}
