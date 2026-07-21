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

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
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
    noctalia,
    flake-utils,
    home-manager,
    nix-darwin,
    sops-nix,
    ...
  }: let
    pkgs = nixpkgs;
    myUsers = import ./users/default.nix {inherit inputs;};
    systemModules = import ./system-modules;
    homeModules = import ./home-modules;
    helpers = import ./helpers;
    lib = lib;
    myLib = import ./lib {inherit lib pkgs; };
    services = import ./services;
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
            lefthook
            go-task
            commitlint-rs
            git
          ];

          shellHook = ''
            lefthook install
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
            inherit inputs self systemModules homeModules myLib services;
          };

          modules =
            systemModules
            ++ services
            ++ helpers
            ++ [
              ./hosts/kkbook
              ./system-modules/common.nix
              ./system-modules/common-linux.nix
              ./system-modules/common-gui-linux.nix
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
                  homeModules.common
                  ++ homeModules.linux
                  ++ [
                    sops-nix.homeManagerModules.sops
                    noctalia.homeModules.default
                  ]
                  ++ helpers;
              }
            ];
        };

        kktab = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs self systemModules homeModules myLib services;
          };

          modules =
            systemModules
            ++ services
            ++ helpers
            ++ [
              ./hosts/kktab
              ./system-modules/common.nix
              ./system-modules/common-linux.nix
              ./system-modules/common-gui-linux.nix
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
                  homeModules.common
                  ++ homeModules.linux
                  ++ [
                    sops-nix.homeManagerModules.sops
                    noctalia.homeModules.default
                  ]
                  ++ helpers;
              }
            ];
        };

        kkserv = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs self systemModules homeModules myLib;
          };

          modules =
            systemModules
            ++ services
            ++ helpers
            ++ [
              ./hosts/kkserv
              ./system-modules/common.nix
              ./system-modules/common-linux.nix
              sops-nix.nixosModules.sops
              myUsers.wisp.system
              myUsers.root.system

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.wisp = myUsers.wisp.home;
                home-manager.users.root = myUsers.root.home;
                # home-manager.sharedModules = map (m: m // {myLib = myLib;}) (
                #   homeModules
                #   ++ [sops-nix.homeManagerModules.sops]
                #   ++ helpers
                # );
                home-manager.extraSpecialArgs = {inherit myLib;};
                home-manager.sharedModules =
                  homeModules.common
                  ++ homeModules.linux
                  ++ [
                    sops-nix.homeManagerModules.sops
                    noctalia.homeModules.default
                  ]
                  ++ helpers;
              }
            ];
        };

        kknas = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs self systemModules homeModules myLib;
          };

          modules =
            systemModules
            ++ services
            ++ helpers
            ++ [
              ./hosts/kknas
              ./system-modules/common.nix
              ./system-modules/common-linux.nix
              sops-nix.nixosModules.sops
              myUsers.wisp.system
              myUsers.root.system

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.wisp = myUsers.wisp.home;
                home-manager.users.root = myUsers.root.home;
                # home-manager.sharedModules = map (m: m // {myLib = myLib;}) (
                #   homeModules
                #   ++ [sops-nix.homeManagerModules.sops]
                #   ++ helpers
                # );
                home-manager.extraSpecialArgs = {inherit myLib;};
                home-manager.sharedModules =
                  homeModules.common
                  ++ homeModules.linux
                  ++ [
                    sops-nix.homeManagerModules.sops
                    noctalia.homeModules.default
                  ]
                  ++ helpers;
              }
            ];
        };
      };

      kkworker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs self systemModules homeModules myLib;
        };

        modules =
          systemModules
          ++ services
          ++ helpers
          ++ [
            ./hosts/kkworker
            ./system-modules/common.nix
            ./system-modules/common-linux.nix
            sops-nix.nixosModules.sops
            myUsers.wisp.system
            myUsers.root.system

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.wisp = myUsers.wisp.home;
              home-manager.users.root = myUsers.root.home;
              # home-manager.sharedModules = map (m: m // {myLib = myLib;}) (
              #   homeModules
              #   ++ [sops-nix.homeManagerModules.sops]
              #   ++ helpers
              # );
              home-manager.extraSpecialArgs = {inherit myLib;};
              home-manager.sharedModules =
                homeModules.common
                ++ homeModules.linux
                ++ [
                  sops-nix.homeManagerModules.sops
                  noctalia.homeModules.default
                ]
                ++ helpers;
            }
          ];
      };

      darwinConfigurations = {
        kg-continabook = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";

          specialArgs = {
            inherit inputs self systemModules homeModules myLib services;
          };

          modules =
            systemModules
            ++ helpers
            ++ [
              ./hosts/kg-continabook
              ./system-modules/common.nix
              ./system-modules/common-darwin.nix
              sops-nix.darwinModules.sops

              home-manager.darwinModules.home-manager
              myUsers.kg.system
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;

                home-manager.users.kg = myUsers.kg.home;

                home-manager.extraSpecialArgs = {
                  inherit myLib;
                };

                home-manager.sharedModules =
                  homeModules.common
                  ++ homeModules.darwin
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
