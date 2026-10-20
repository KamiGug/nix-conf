{
  description = "My nix based OS configs";

  inputs = {
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
    nixpkgs,
    flake-utils,
    ...
  }: let
    flakeLib = import ./src/lib/flake {};
    linuxHosts = flakeLib.readHosts {inherit inputs;} {dir = ./src/hosts/linux;};
    darwinHosts = flakeLib.readHosts {inherit inputs;} {dir = ./src/hosts/darwin;};

    isoHosts = nixpkgs.lib.filterAttrs (_: h: h.args.iso or false) linuxHosts;
    nixosHosts = nixpkgs.lib.filterAttrs (_: h: !(h.args.iso or false)) linuxHosts;
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
            shellcheck
            shfmt
            stylua
            kdlfmt
            yamlfmt
            jsonfmt
            lefthook
            go-task
            commitlint-rs
            git
            opencode

            yq
            jinja2-cli
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

      overlays = {
        default = import ./src/overlays {inherit inputs;};
      };

      nixosConfigurations = builtins.mapAttrs (name: host:
        flakeLib.mkLinuxHost (host.args // {inherit inputs name;}))
      nixosHosts;
      isoConfigurations = builtins.mapAttrs (name: host:
        flakeLib.mkIsoHost (builtins.removeAttrs host.args ["iso"]
          // {inherit inputs name;}))
      isoHosts;
      darwinConfigurations = builtins.mapAttrs (name: host:
        flakeLib.mkDarwinHost (host.args // {inherit inputs name;}))
      darwinHosts;
    };
}
