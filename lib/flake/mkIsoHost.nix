{
  inputs,
  name ? "installer",
  users ? ["peasant"],
  root ? ../..,
  extraModules ? [],
}:
assert (builtins.isString name) || throw "name must be a string";
assert (builtins.isList users && users != []) || throw "users must be a non empty list";
assert (builtins.isPath root && builtins.pathExists (root + "/flake.nix")) || throw "root needs to be a path to the root of the project";
assert (builtins.isList extraModules) || throw "extraModules must be a list"; let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  myUsers = import (root + "/users") {inherit inputs;};
  systemModules = import (root + "/system-modules");
  homeModules = import (root + "/home-modules");
  helpers = import (root + "/helpers");
  services = import (root + "/services");
  myLib = import (root + "/lib") {inherit pkgs;};
  localOverlay = import (root + "/overlays") {inherit inputs;};

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
        (root + "/hosts/${name}")
        inputs.home-manager.nixosModules.home-manager
        homeManagerConfig
        {nixpkgs.overlays = [localOverlay];}
      ]
      ++ userSystemModules
      ++ extraModules;
  }
