{...}: final: prev: let
  scanPkgs = import ../lib/scan-pkgs.nix {
    pkgs = final;
    inherit (prev) lib;
  };
in
  scanPkgs ../pkgs
