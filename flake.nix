{
  description = "My nix based OS configs";

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/?ref=nixos-25.05";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri = {
    #   url = "github:niri-wm/niri";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.rust-overlay.follows = "";
    # };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-stable,
    nixpkgs-unstable,
    flake-utils,
    home-manager,
    sops-nix,
    ...
  }: let
    myUsers = import ./users/default.nix {inherit inputs;};
    systemModules = import ./system-modules;
    homeModules = import ./home-modules;
    helpers = import ./helpers;
    myLib = import ./lib { pkgs = nixpkgs; };
  in
    # Merge per-system outputs with global outputs
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            sops
            git
            vim
            openssh
            go-task
            lefthook
            alejandra
            statix
            deadnix
          ];

          shellHook = ''
            echo "NixOS admin shell for ${system}"
          '';
        };

        formatter = pkgs.alejandra;
      }
    )
    // {
      overlays = [
        (import ./overlays {inherit inputs;})
      ];

      nixosConfigurations = {
        kkbook = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs self systemModules homeModules myLib;
          };

          modules =
            helpers
            ++ [
              ./hosts/kkbook
              ./system-modules/common.nix
              ./system-modules/common-linux.nix
              sops-nix.nixosModules.sops
              myUsers.peon.system
              myUsers.root.system

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.peon = myUsers.peon.home;
                home-manager.users.root = myUsers.root.home;
                # home-manager.sharedModules = map (m: m // {myLib = myLib;}) (
                #   homeModules
                #   ++ [sops-nix.homeManagerModules.sops]
                #   ++ helpers
                # );
                home-manager.extraSpecialArgs = {inherit myLib;};
                home-manager.sharedModules =
                  homeModules
                  ++ [
                    sops-nix.homeManagerModules.sops
                  ]
                  ++ helpers;
              }
            ];
        };
      };
    };
}
