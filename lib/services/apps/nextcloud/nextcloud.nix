{
  pkgs,
  image ? "nextcloud:31",
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
    NEXTCLOUD_TRUSTED_DOMAINS =
      domain;
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
  ports = [
    (containerLib.mkPort {
      host = 8080;
      container = 80;
    })
  ];
}
