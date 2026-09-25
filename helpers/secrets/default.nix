{
  # config,
  lib,
  myLib,
  ...
}: let
  secretsFile = ../secrets.yml;

  simpleConf = name: {
    format = "yaml";
    sopsFile = secretsFile;
    key = name;
  };

  secrets = lib.foldl'
    lib.recursiveUpdate
    {}
    [
      (import ./hosts)
      (import ./services)
      (import ./ssh)
      (import ./users)
    ]
  ;
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
