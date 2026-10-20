{lib, ...}: {
  readModules = {
    dir,                    # path to scan
    mode ? "set",           # "set" | "array"
    stopOnDefault ? true,   # stop at dirs containing default.nix
  }:
    assert builtins.isPath dir || throw "dir must be a path";
    assert builtins.elem mode ["set" "array"]
      || throw "mode must be one of \"set\", \"array\"";
    let
      walk = d: let
        entries = builtins.readDir d;   # sorted by name
      in
        if stopOnDefault && entries ? "default.nix"
        then [d]                         # the dir itself is the module
        else lib.concatMap
              (name: let
                 p = d + "/${name}";
                 kind = entries.${name};
               in
                 if kind == "directory"
                 then walk p
                 else lib.optional (kind == "regular" && lib.hasSuffix ".nix" name) p)
              (builtins.attrNames entries);

      leavesOf = name: kind: let
        p = dir + "/${name}";
      in
        if kind == "directory"
        then walk p
        else lib.optional (kind == "regular" && lib.hasSuffix ".nix" name) p;

      top = builtins.readDir dir;
      keyOf = name: kind:
        if kind == "directory" then name
        else lib.removeSuffix ".nix" name;
    in
      if mode == "array"
      then walk dir
      else builtins.listToAttrs (map
        (name: {
          name = keyOf name top.${name};
          value = leavesOf name top.${name};
        })
        (builtins.attrNames top));
}
