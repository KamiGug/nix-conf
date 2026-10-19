{inputs, ...}: final: prev: let
  scanPkgs = import ../lib/scan-pkgs.nix {
    pkgs = final;
    lib = prev.lib;
  };
in
  scanPkgs ../pkgs
