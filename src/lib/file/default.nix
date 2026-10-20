{...} @ args: {
  ensureDirExists = import ./ensureDirExists.nix args;
  mkMutableFile = import ./mkMutableFile.nix args;
  mkRandomSecret = import ./mkRandomSecret.nix args;
}
