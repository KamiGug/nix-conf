{
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  clone = pkgs.callPackage ../../pkgs/nix-conf-clone {};
  install = pkgs.callPackage ../../pkgs/nix-conf-install {nix-conf-clone = clone;};
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix")

    ../../system-modules/common.nix
    ../../system-modules/common-linux.nix
  ];

  # common-linux disables the X server, which the graphical installer needs.
  services.xserver.enable = lib.mkForce true;

  # The nixpkgs installer profiles hardcode the `nixos` live user.
  services.displayManager.autoLogin.user = lib.mkForce "peasant";
  services.getty.autologinUser = lib.mkForce "peasant";
  nix.settings.trusted-users = ["peasant"];

  # The live user has no password, so `security.sudo.wheelNeedsPassword` cannot
  # authenticate. Grant this ISO-only account passwordless sudo explicitly.
  security.sudo.extraRules = [
    {
      users = ["peasant"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  isoImage.edition = "kksys";

  # The live environment has no access to the sops age key; secrets are
  # decrypted on the installed system instead.
  environment.systemPackages = [clone install];
}
