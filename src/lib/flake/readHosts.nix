{inputs}: {
  dir,   # e.g. ./src/hosts/linux
}: let
  entries = builtins.readDir dir;             # sorted by name
  dirs = builtins.filter (n: entries.${n} == "directory")
    (builtins.attrNames entries);
  isHost = n: builtins.pathExists (dir + "/${n}/default.nix");
  hostDirs = builtins.filter isHost dirs;
  strays = builtins.filter (n: !isHost n) dirs;
in
  assert builtins.isPath dir || throw "dir must be a path";
  assert strays == [] || throw
    "readHosts ${toString dir}: directories without default.nix: ${toString strays}";
  builtins.listToAttrs (map (name: {
      inherit name;
      value = {
        path = dir + "/${name}";
        args =
          if builtins.pathExists (dir + "/${name}/host.nix")
          then import (dir + "/${name}/host.nix") {inherit inputs;}
          else {};
      };
    })
    hostDirs)
