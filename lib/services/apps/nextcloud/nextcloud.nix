{
  pkgs,
  image ? "nexcloud:31",
  configArgs,
  volumePrefix ? "/mnt/nas/",
  selfPrefix ? "nextcloud"
}:
let
  validators = import ../../validators;
  containerLib = import ../..;
  domain = if configArgs ? domain
    then configArgs.domain
    else "file.${configArgs.rootDomain}";
  testText = pkgs.writeText "someTest";
  testScript = pkgs.writeScript "echo hello!";
in

assert configArgs ? rootDomain;
assert configArgs ? protocol;
assert validators.domain domain;

containerLib.mkContainerService {
  inherit image;
  name = "nextcloud";
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
    (
      containerLib.mkVolume {
        hostPath = testText;
        containerPath = "/test.txt";
      }
    )
    (
      containerLib.mkVolume {
        hostPath = testScript;
        containerPath = "/test.exe";
      }
    )
  ];
  ports = [
    containerLib.mkPort {
      host = 8080;
      container = 80;
    }
  ];
}
