{inputs}: {
  dir,                    # e.g. ./src/users
}: let
  entries = builtins.readDir dir;             # sorted by name
  names = builtins.attrNames entries;
  isUserFile =
    n: n != "default.nix"
    && entries.${n} == "regular"
    && builtins.hasSuffix ".nix" n;
in
  assert builtins.isPath dir || throw "dir must be a path";
  assert ! builtins.elem "default.nix" names
    || throw "readUsers ${toString dir}: users/default.nix registry still present — delete it (users are scanned now)";
  assert (builtins.all (n: entries.${n} == "regular") names)
    || throw "readUsers ${toString dir}: only regular .nix files allowed (directories are not users): ${toString (builtins.filter (n: entries.${n} != "regular") names)}";
  builtins.listToAttrs
    (map
      (file:
        let
          name = builtins.baseNameOf file;
          user = import (dir + "/${file}") {inherit inputs;};
        in
          assert user ? system && user ? home
            || throw "readUsers ${toString dir}/${file}: user must provide {system, home}";
          {inherit name; value = user;})
      (builtins.filter isUserFile names))
