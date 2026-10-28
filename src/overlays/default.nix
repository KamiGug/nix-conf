{inputs, ...}: final: prev: let
  scanPkgs = import ../lib/scanPkgs.nix {
    pkgs = final;
    inherit (prev) lib;
  };
in
  scanPkgs ../pkgs
  // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
    disko = inputs.disko.packages.${prev.stdenv.hostPlatform.system}.disko;
  }
