{
  inputs,
  name,
  arch ? "arm",
  users ? null,
  extraModules ? [],
  root ? ../..,
}:
assert (builtins.isString name) || throw "name must be a string";
assert (builtins.elem arch ["x86" "arm"]) || throw "arch must be one of the following 'x86', 'arm'";
assert (builtins.isList users && users != [] || users == null) || throw "users needs to be a non empty list or null (for default values)";
assert (builtins.isPath root && builtins.pathExists (root + "/flake.nix")) || throw "root needs to be a path to the root of the project";
assert (builtins.isList extraModules) || throw "extraModules must be a list"; let
  defaultUsers = ["acolyte"];
  resolvedUsers =
    if users == null
    then defaultUsers
    else users;

  hostConfig = import ./_resolveHostSet.nix {
    inherit inputs name arch root extraModules;
    os = "darwin";
    users = resolvedUsers;
    gui = false;
  };
in
  inputs.nix-darwin.lib.darwinSystem hostConfig
