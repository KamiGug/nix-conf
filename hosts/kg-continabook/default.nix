{
  config,
  pkgs,
  ...
}: {
  networking.hostName = "kg-continabook";
  users.users.kg = {
    home = "/Users/kg";
  };
  system.primaryUser = "kg";
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}
