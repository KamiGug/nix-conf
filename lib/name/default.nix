
{pkgs, ...}: {
  secret = import ./secret.nix {inherit pkgs;};
  services = import ./services {inherit pkgs;};
}
