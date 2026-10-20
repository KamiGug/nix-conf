args: let
  parsedArgs = args // {lib = args.pkgs.lib;};
  fs = import ./fs.nix parsedArgs;
  tree = fs.readModules {
    dir = ./.;
    mode = "set";
  };
  resolve = paths:
    if builtins.length paths == 1
    then import (builtins.head paths) parsedArgs
    else throw "src/lib entry must resolve to exactly one module";
in
  builtins.mapAttrs (_: resolve) (builtins.removeAttrs tree ["default"])
