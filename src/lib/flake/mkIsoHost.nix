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
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  myUsers = import (root + "/src/users") {inherit inputs;};
  systemModules = import (root + "/src/system-modules");
  homeModules = import (root + "/src/home-modules");
  helpers = import (root + "/src/helpers");
  services = import (root + "/src/services");
  myLib = import (root + "/src/lib") {inherit pkgs;};
  localOverlay = import (root + "/src/overlays") {inherit inputs;};

  userSystemModules = map (user: myUsers.${user}.system) users;

  homeManagerUsers = builtins.listToAttrs (
    map (user: {
      name = user;
      value = myUsers.${user}.home;
    })
    users
  );

  homeManagerConfig = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users = homeManagerUsers;
    home-manager.extraSpecialArgs = {inherit myLib;};
    home-manager.sharedModules =
      homeModules.common
      ++ helpers
      ++ [inputs.sops-nix.homeManagerModules.sops];
  };
in
  inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {inherit inputs systemModules homeModules myLib services;};
    modules =
      [
        (root + "/src/hosts/${name}")
        inputs.home-manager.nixosModules.home-manager
        homeManagerConfig
        {nixpkgs.overlays = [localOverlay];}
      ]
      ++ userSystemModules
      ++ extraModules;
  }
