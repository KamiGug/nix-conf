{ pkgs }:

let
  lib = pkgs.lib;
  scan = rootPath: currentPath:
    let
      entries = builtins.readDir currentPath;
      isRoot = rootPath == currentPath;
    in
    if !isRoot && entries ? "default.nix" then
      pkgs.callPackage currentPath { }
    else
      let
        processItem = name: type:
          let
            fullPath = currentPath + "/${name}";
          in
          if type == "directory" then
            let
              result = scan rootPath fullPath;
            in
              if result == {} then null else { inherit name; value = result; }
          else if type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" then
            {
              name = lib.removeSuffix ".nix" name;
              value = pkgs.callPackage fullPath { };
            }

          else
            null;
        rawList = lib.mapAttrsToList processItem entries;
        validList = builtins.filter (x: x != null) rawList;
      in
        builtins.listToAttrs validList;

in
targetDir: scan targetDir targetDir
