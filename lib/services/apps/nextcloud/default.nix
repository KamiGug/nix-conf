{pkgs, ...} :
{
  # pkgs,
  configArgs ? {},
  images ? { nextcloud =  "docker.io/library/nextcloud:31"; onlyoffice = ""; },
}:

let
  lib = pkgs.lib;
  validators = import ../../../validators;
  # containerLib = import ../.. {inherit pkgs;};
  nextcloud = import ./nextcloud.nix;
  # onlyoffice = import ./onlyoffice.nix;

  parsedConfigArgs = lib.recursiveUpdate {
    protocol = "http";
    nameSuffix = "";
    volumePrefix = "/mnt/nas";
    volumeSelfPrefix = {
      nextcloud = "nextcloud";
      onlyoffice = "onlyoffice";
    };
    serviceUser = "wisp";
    networks = {
      nextcloud = [];
      onlyoffice = [];
    };
  } configArgs;

  nextcloudArgs = parsedConfigArgs // {
    volumeSelfPrefix = parsedConfigArgs.volumeSelfPrefix.nextcloud;
    networks = parsedConfigArgs.networks.nextcloud;
  };

  # onlyofficeArgs = parsedConfigArgs // {
  #   volumeSelfPrefix = parsedConfigArgs.volumeSelfPrefix.onlyoffice;
  #   networks = parsedConfigArgs.networks.onlyoffice;
  # };

in

assert (images ? nextcloud);
assert (images ? onlyoffice);
# assert (parsedConfigArgs ? domain && validators.domain parsedConfigArgs.domain)
#   || (parsedConfigArgs ? rootDomain && validators.domain parsedConfigArgs.rootDomain);
assert builtins.elem parsedConfigArgs.protocol [ "http" "https" ];
# TODO: add more asserts (at least one each)

nextcloud {
  inherit pkgs;
  configArgs = nextcloudArgs;
  image = images.nextcloud;
}
# // onlyoffice {
#   inherit pkgs;
#   configArgs = onlyofficeArgs;
#   image = images.onlyoffice;
# }
