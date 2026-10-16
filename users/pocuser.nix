{
  # inputs,
  ...
}: {
  system = {config, ...}: {
    users.users.pocuser = {
      isNormalUser = true;
      description = "sops POC user";
      home = "/home/pocuser";
      extraGroups = ["wheel"];
      hashedPasswordFile = config.sops.secrets."pocuser-password".path;
    };
  };
  home = {
    # pkgs,
    ...
  }: {
    home.username = "pocuser";
    home.homeDirectory = "/home/pocuser";
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;
  };
}
