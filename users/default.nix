{...} @ inputs: {
  root = import ./root.nix inputs;
  peon = import ./peon.nix inputs;
  wisp = import ./wisp.nix inputs;
  kg = import ./kg.nix inputs;
  peasant = import ./peasant.nix inputs;
}
