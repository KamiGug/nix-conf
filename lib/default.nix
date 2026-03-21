{pkgs, ...} @ inputs: {
  template = import ./template.nix;
  scanPkgs = import ./scan-pkgs.nix { inherit pkgs; };
}
