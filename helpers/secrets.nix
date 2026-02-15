{
  # config,
  lib,
  ...
}: let
  secretsFile = ../secrets.yml;

  simpleConf = name: {
    format = "yaml";
    sopsFile = secretsFile;
    key = name;
  };

  secrets = {
    peon-password = {
      # neededForUsers = true;
    };

    github-priv-key = {};

    ananas-priv-key = {};
  };
in {
  sops.age.keyFile = lib.mkDefault "/etc/sops/age.key";
  sops.secrets =
    lib.mapAttrs
    (
      name: extra:
        simpleConf name // extra
    )
    secrets;
}
