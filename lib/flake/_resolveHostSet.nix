{
  inputs,
  name,
  arch,
  os,
  gui,
  users,
  root,
  enableHm ? true
}:
assert (builtins.isString name) || throw "name must be a string";
assert (builtins.elem arch ["x86" "arm"]) || throw "arch must be one of the following 'x86', 'arm'";
assert (builtins.elem os ["linux" "darwin"]) || throw "os must be one of the following 'linux', 'darwin'";
assert (builtins.isList users && users != []) || throw "users must be a non empty list";
assert (builtins.isBool gui) || throw "gui must be bool";
assert (builtins.isPath root && builtins.pathExists (root + "/flake.nix")) || throw "root needs to be a path to the root of the project";
assert (builtins.isBool enableHm) || throw "enableHm must be bool";
let
  lib = inputs.nixpkgs.lib;

  inherit (inputs) nixpkgs;

  systemFromArch = {
     x86 = {
       linux = "x86_64-linux";
       darwin = "x86_64-darwin";
     };

     arm = {
       linux = "aarch64-linux";
       darwin = "aarch64-darwin";
     };
   };
  system = systemFromArch.${arch}.${os};
  pkgs = nixpkgs.legacyPackages.${system};
  myUsers = import (lib.path.append root "users") { inherit inputs; };
  systemModules = import (lib.path.append root "system-modules");
  homeModules = import (lib.path.append root "home-modules");
  helpers = import (lib.path.append root "helpers");
  services = import (lib.path.append root "services");
  myLib = import (lib.path.append root "lib") { inherit pkgs; };

  userSystemModules =
    map (name: myUsers.${name}.system) users;

  homeManagerUsers =
    builtins.listToAttrs (
      map (name: {
        name = name;
        value = myUsers.${name}.home;
      }) users
    );
  commonModules = [
    (lib.path.append root "system-modules/common.nix")
  ]
  ++ (
    if os == "linux" then
    [
      (lib.path.append root "system-modules/common-linux.nix")
    ]
    ++ lib.optional gui (lib.path.append root "system-modules/common-gui-linux.nix")
    else
    [
      (lib.path.append root "system-modules/common-darwin.nix")
    ]
  );

  # modulesName = "${system}Modules";
  # sopsModule = inputs.sops-nix.${modulesName}.sops;
  # homeManagerModule = inputs.home-manager.${modulesName}.home-manager;

  platformModules = if os == "linux" then inputs.sops-nix.nixosModules else inputs.sops-nix.darwinModules;
  sopsModule = platformModules.sops;

  # TODO: handle enableHm == false
  hmPlatformModules = if os == "linux" then inputs.home-manager.nixosModules else inputs.home-manager.darwinModules;
  homeManagerModule = hmPlatformModules.home-manager;

  homeManagerConfig = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    home-manager.users = homeManagerUsers;

    home-manager.extraSpecialArgs = {
      inherit myLib;
    };

  home-manager.sharedModules =
    homeModules.common
    ++ homeModules.${os}
    ++ lib.optional gui
      inputs.noctalia.homeModules.default
    ++ helpers
    ++ [
      inputs.sops-nix.homeManagerModules.sops
    ];
  };

  modules =
    commonModules
    ++ systemModules
    ++ helpers
    ++ [
      (lib.path.append root "hosts/${name}")
      sopsModule
      homeManagerModule
      homeManagerConfig
    ]
    ++ userSystemModules;

in
{
  inherit system modules;
  specialArgs = {
    inherit inputs systemModules homeModules myLib services;
  };
}
