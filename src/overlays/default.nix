{...}: final: prev: let
  scanPkgs = import ../lib/scanPkgs.nix {
    pkgs = final;
    inherit (prev) lib;
  };
in
  scanPkgs ../pkgs
