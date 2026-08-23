{
  pkgs,
  image ? "docker.io/library/nextcloud:31",
  configArgs,
}:
let
  lib = pkgs.lib;
  containerLib = import ../.. {inherit pkgs;};
  domain = if configArgs ? domain
    then configArgs.domain
    else "file.${configArgs.rootDomain}";
  testScript = pkgs.writeScriptBin "test-script" "echo hello!";

  volumes = {
    data = "/var/www/html/data";
    config = "/var/www/html/config";
    apps = "/var/www/html/apps";
    custom_apps = "/var/www/html/custom_apps";
  };

  hostPaths = lib.mapAttrsToList (name: _:
    "${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name}"
  ) volumes;

  volumeMounts = lib.mapAttrsToList (name: containerPath:
    containerLib.mkVolume {
      hostPath = "${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name}";
      inherit containerPath;
    }
  ) volumes;
  in
assert configArgs ? rootDomain || configArgs ? domain;
assert configArgs ? protocol;
# assert validators.domain domain;
{
  environment.systemPackages = [ testScript ];
  systemd.tmpfiles.rules =
  [
    "d ${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}"
      "750 ${configArgs.user} root -"
  ]
  # ;
  ++ lib.mapAttrsToList (name: _:
        "d ${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name} 0750 ${configArgs.user} root -"
      ) volumes;

}
// containerLib.mkContainerService {
  inherit image;
  name = "nextcloud${configArgs.nameSuffix}";
  # name = "nextcloud";
  environment = {
    NEXTCLOUD_TRUSTED_DOMAINS = domain;
    serverName = "${configArgs.protocol}://${domain}";
  };
  volumes =
  [

    # (containerLib.mkVolume {
    #   hostPath =
    #     "${volumePrefix}/${selfPrefix}/data";

    #   containerPath =
    #     "/var/www/html";
    # })
    (
      containerLib.mkVolume {
        hostPath = testScript;
        containerPath = "/test.exe";
      }
    )
  ]
  # ;
  ++ volumeMounts;

  # TODO: remove the ports! will need correct network + reverse proxy
  ports = [
    "8080:80"
  ];
}
