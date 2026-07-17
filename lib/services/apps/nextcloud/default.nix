{ myLib }:
{
  volumePrefix,
  configArgs ? {},
  image ? "nextcloud:31",
}:
let
  domain =
    configArgs.domain;
in
assert configArgs ? domain;
assert myLib.validators.domain domain;

myLib.containers.mkContainerService {
  name = "nextcloud";
  inherit image;
  environment = {
    NEXTCLOUD_TRUSTED_DOMAINS =
      domain;
  };
  volumes = [
    (myLib.containers.mkVolume {
      hostPath =
        "${volumePrefix}/nextcloud/data";

      containerPath =
        "/var/www/html";
    })
  ];

}
