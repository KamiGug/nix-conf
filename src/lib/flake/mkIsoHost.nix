{
  inputs,
  name ? "installer",
  users ? ["peasant"],
  root ? ../../..,
  extraModules ? [],
}:
assert (builtins.isString name) || throw "name must be a string";
assert (builtins.isList users && users != []) || throw "users must be a non empty list";
assert (builtins.isPath root && builtins.pathExists (root + "/flake.nix")) || throw "root needs to be a path to the root of the project";
assert (builtins.isList extraModules) || throw "extraModules must be a list"; let
  resolved = import ./_resolveHostSet.nix {
    inherit inputs name root extraModules;
    arch = "x86";
    os = "linux";
    gui = false;
    inherit users;
  };
in
  inputs.nixpkgs.lib.nixosSystem {
    inherit (resolved) system modules specialArgs;
  }
