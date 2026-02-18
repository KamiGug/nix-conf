{...} @ inputs: {
  root = import ./root.nix inputs;
  peon = import ./peon.nix inputs;
  peonNoGui = import ./peon-no-gui.nix inputs;
}
