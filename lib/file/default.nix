{...} @ args: {
  ensureDirExists = import ./ensureDirExists.nix;
  mkMutableFile = import ./mkMutableFile.nix;
  mkRandomSecret = import ./mkRandomSecret.nix;
}
