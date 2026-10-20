{inputs, ...}: {
  gui = true;
  extraModules = [inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel];
}
