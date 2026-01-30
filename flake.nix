{
  description = "My nix based OS configs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, sops-nix, ... }:
    let inherit (self) outputs;
      systems = [
        "aarch64-linux"
          "i686-linux"
          "x86_64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      myUsers = import ./users/default.nix { inherit inputs; };
      systemModules = import ./system-modules;
      homeModules = import ./home-modules;
    in {
    # packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      overlays = [ (import ./overlays { inherit inputs; }) ];


    nixosConfigurations = {
      kkbook = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs self outputs systemModules homeModules;
        };

        modules = [
          ./hosts/kkbook
          ./system-modules/common.nix
          ./system-modules/common-linux.nix
          sops-nix.nixosModules.sops
          myUsers.peon.system
	  myUsers.root.system
          
	  home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.peon = myUsers.peon.home;
            home-manager.users.root = myUsers.root.home;
	    home-manager.sharedModules = homeModules;
          }
        ];

      };
    };
  };
}
