_args: {
  mkLinuxHost = import ./mkLinuxHost.nix;
  mkDarwinHost = import ./mkDarwinHost.nix;
  mkIsoHost = import ./mkIsoHost.nix;
  readHosts = import ./readHosts.nix;
  readUsers = import ./readUsers.nix;
}
