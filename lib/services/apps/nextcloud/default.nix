{pkgs, ...}:
{
  volumePrefix ? "/mnt/nas/",
  configArgs ? {},
  images ? { nextcloud =  "docker.io/library/nextcloud:31"; onlyoffice = ""; },
}:

let
  lib = pkgs.lib;
  validators = import ../../../validators;
  # containerLib = import ../.. {inherit pkgs;};
  nextcloud = import ./nextcloud.nix;

  parsedConfigArgs = lib.recursiveUpdate {
    protocol = "http";
    namePrefix = "";
    nameSuffix = "";
  } configArgs;
in

assert (images ? nextcloud);
assert (images ? onlyoffice);
# assert (parsedConfigArgs ? domain && validators.domain parsedConfigArgs.domain)
#   || (parsedConfigArgs ? rootDomain && validators.domain parsedConfigArgs.rootDomain);
assert builtins.elem parsedConfigArgs.protocol [ "http" "https" ];

nextcloud {
  configArgs = parsedConfigArgs;
  inherit pkgs volumePrefix;
  image = images.nextcloud;
}
