{pkgs, lib, ...}:
{
  volumePrefix ? "/mnt/nas/",
  configArgs ? {},
  images ? { nextcloud =  "nextcloud:31"; onlyoffice = ""; },
}:

let
  validators = import ../../validators;
  # containerLib = import ../..;
  nextcloud = import ./nextcloud.nix;

  configArgs = lib.recursiveUpdate {
    protocol = "http";
  } configArgs;
in

assert configArgs ? rootDomain;
assert images ? nextcloud;
assert images ? onlyoffice;
assert validators.domain configArgs.rootDomain;
assert builtins.elem configArgs.protocol [ "http" "https" ];

nextcloud {
  inherit pkgs volumePrefix configArgs;
  image = images.nextcloud;
}
