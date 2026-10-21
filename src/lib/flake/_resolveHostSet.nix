{
  inputs,
  name,
  arch,
  os,
  gui,
  users,
  root,
  extraModules ? [],
  enableHm ? true,
}:
assert (builtins.isString name) || throw "name must be a string";
assert (builtins.elem arch ["x86" "arm"]) || throw "arch must be one of the following 'x86', 'arm'";
assert (builtins.elem os ["linux" "darwin"]) || throw "os must be one of the following 'linux', 'darwin'";
assert (builtins.isList users && users != []) || throw "users must be a non empty list";
assert (builtins.isBool gui) || throw "gui must be bool";
assert (builtins.isPath root && builtins.pathExists (root + "/flake.nix")) || throw "root needs to be a path to the root of the project";
assert (builtins.isList extraModules) || throw "extraModules must be a list";
assert (builtins.isBool enableHm) || throw "enableHm must be bool"; let
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
  fs = import (lib.path.append root "src/lib/fs.nix") {inherit lib;};
  systemModules = fs.readModules {
    dir = lib.path.append root "src/modules/system";
    mode = "set";
  };
  homeModules = fs.readModules {
    dir = lib.path.append root "src/modules/home";
    mode = "set";
  };
  helpers = import (lib.path.append root "src/helpers");
  myLib = import (lib.path.append root "src/lib") {inherit pkgs;};
  localOverlay = import (lib.path.append root "src/overlays") {inherit inputs;};
  myUsers = myLib.flake.readUsers {inherit inputs;} {
    dir = lib.path.append root "src/users";
  };

  userSystemModules =
    map (name: myUsers.${name}.system) users;

  homeManagerUsers = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = myUsers.${name}.home;
    })
    users
  );
  # modulesName = "${system}Modules";
  # sopsModule = inputs.sops-nix.${modulesName}.sops;
  # homeManagerModule = inputs.home-manager.${modulesName}.home-manager;

  platformModules =
    if os == "linux"
    then inputs.sops-nix.nixosModules
    else inputs.sops-nix.darwinModules;
  sopsModule = platformModules.sops;

  hmPlatformModules =
    if os == "linux"
    then inputs.home-manager.nixosModules
    else inputs.home-manager.darwinModules;
  homeManagerModule = lib.optional enableHm hmPlatformModules.home-manager;

  homeManagerConfig = lib.mkIf enableHm {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    home-manager.users = homeManagerUsers;

    home-manager.extraSpecialArgs = {
      inherit myLib;
    };

    home-manager.sharedModules =
      homeModules.common
      ++ homeModules.${os}
      ++ lib.optional (gui && os == "linux")
      inputs.noctalia.homeModules.default
      ++ helpers
      ++ [
        inputs.sops-nix.homeManagerModules.sops
      ];
  };

  modules =
    systemModules.common
    ++ (
      if os == "linux"
      then systemModules.linux
      else systemModules.darwin
    )
    ++ lib.optionals
    (gui && os == "linux")
    (fs.readModules {
      dir = lib.path.append root "src/modules/system/gui";
      mode = "array";
    })
    ++ helpers
    ++ [
      (lib.path.append root "src/hosts/${os}/${name}")
      sopsModule
    ]
    ++ homeManagerModule
    ++ [
      homeManagerConfig
      {nixpkgs.overlays = [localOverlay];}
    ]
    ++ userSystemModules
    ++ extraModules;
in {
  inherit system modules;
  specialArgs = {
    inherit inputs systemModules homeModules myLib;
  };
}
