{
  pkgs,
  image ? "docker.io/library/nextcloud:31",
  configArgs,
  volumePrefix ? "/mnt/nas/",
  selfPrefix ? "nextcloud"
}:
let
  validators = import ../../../validators;
  containerLib = import ../.. {inherit pkgs;};
  domain = if configArgs ? domain
    then configArgs.domain
    else "file.${configArgs.rootDomain}";
  # testScript = pkgs.writeScriptBin "test-script" "echo hello!";
in

assert configArgs ? rootDomain || configArgs ? domain;
assert configArgs ? protocol;
# assert validators.domain domain;
# {
#   environment.systemPackages = [ testScript ];
# } //
containerLib.mkContainerService {
  inherit image;
  name = "${configArgs.namePrefix}nextcloud${configArgs.nameSuffix}";
  environment = {
    NEXTCLOUD_TRUSTED_DOMAINS = domain;
    serverName = "${configArgs.protocol}://${domain}";
  };
  volumes = [
    (containerLib.mkVolume {
      hostPath =
        "${volumePrefix}/${selfPrefix}/data";

      containerPath =
        "/var/www/html";
    })
    # (
    #   containerLib.mkVolume {
    #     hostPath = testScript;
    #     containerPath = "/test.exe";
    #   }
    # )
  ];
  # TODO: remove the ports! will need correct network + reverse proxy
  ports = [
    "8080:80"
  ];
}
