{
  inputs,
  name,
  arch ? "x86",
  gui ? false,
  users ? null,
  root ? ../..,
  extraModules ? [],
}:
assert (builtins.isString name) || throw "name must be a string";
assert (builtins.elem arch ["x86" "arm"]) || throw "arch must be one of the following 'x86', 'arm'";
assert (builtins.isBool gui) || throw "gui must be a bool value";
assert (builtins.isList users && users != [] || users == null) || throw "users needs to be a non empty list or null (for default values)";
assert (builtins.isPath root && builtins.pathExists (root + "/flake.nix")) || throw "root needs to be a path to the root of the project";
assert (builtins.isList extraModules) || throw "extraModules must be a list"; let
  defaultUsers =
    if gui
    then ["peon"]
    else ["wisp"];

  resolvedUsers =
    if users == null
    then defaultUsers
    else users;

  hostConfig = import ./_resolveHostSet.nix {
    inherit inputs name arch gui root extraModules;
    os = "linux";
    users = resolvedUsers;
  };
  inherit (inputs) nixpkgs;
in
  nixpkgs.lib.nixosSystem hostConfig
