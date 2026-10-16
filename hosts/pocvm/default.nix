# Temporary POC host: a plain QEMU VM with a sops-managed user password.
# Delete this host directory, the `pocuser` user and the flake entry once done.
{...}: {
  networking.hostName = "pocvm";

  system.stateVersion = "25.11";

  # `neededForUsers` secrets are decrypted (to /run/secrets-for-users) before
  # users and groups are activated, so the hashedPasswordFile below exists by
  # the time `pocuser` is created on first boot.
  sops.secrets."pocuser-password" = {
    neededForUsers = true;
    sopsFile = ./passwords.yml;
  };

  users.mutableUsers = false;

  # Everything below only applies to the generated VM. qemu-vm.nix is not part
  # of the default module list; it is pulled in through `virtualisation.vmVariant`
  # (see nixos/modules/virtualisation/build-vm.nix).
  virtualisation.vmVariant = {
    # The VM has no age key of its own, so share the host's key over 9p. Shares
    # are mounted in stage-1 (neededForBoot), i.e. before activation scripts run.
    # `securityModel = "none"` makes the guest read the files as the qemu user.
    virtualisation.sharedDirectories.poc-age-key = {
      source = "/etc/sops";
      target = "/mnt/poc-age-key";
      securityModel = "none";
    };
    sops.age.keyFile = "/mnt/poc-age-key/age.key";
  };
}
