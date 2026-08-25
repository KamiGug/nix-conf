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

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
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
    flake-utils,
    home-manager,
    nix-darwin,
    sops-nix,
    nixos-hardware,
    ...
  }: let
    flakeLib = import ./lib/flake;
    nixosHosts = {
      kkbook = { gui = true; };
      kktab = { };
      kkserv = { };
      kknas = { };
      kkworker = { };
    };

    darwinHosts = {
      kg-continabook = { users = [ "kg" ]; };
    };
  in
  # TODO: split shells to seperate file
  flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          SOPS_AGE_KEY_FILE = "/etc/sops/age.key";
          packages = with pkgs; [
            sops
            openssh
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
      # inherit services systemModules homeModules helpers myUsers;

      overlays = [
        (import ./overlays {inherit inputs;})
      ];

      nixosConfigurations = builtins.mapAttrs
         (name: hostArgs:
           flakeLib.mkLinuxHost (
             hostArgs // {
               inherit inputs name;
             }
           )
         )
         nixosHosts;
      darwinConfigurations = builtins.mapAttrs
          (name: hostArgs:
            flakeLib.mkDarwinHost (
              hostArgs // {
                inherit inputs name;
              }
            )
          )
          darwinHosts;
    };
}
