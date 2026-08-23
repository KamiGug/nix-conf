{pkgs, ...} :
{
  configArgs ? {},
  image ? "docker.io/library/postgres:18.6",
}@args:

let
  lib = pkgs.lib;
  containerLib = import ../.. {inherit pkgs;};
  validators = import ../../../validators;
  # containerLib = import ../.. {inherit pkgs;};

  configArgs = lib.recursiveUpdate {
    # protocol = "http";
    nameSuffix = "";
    volumePrefix = "/mnt/nas";
    volumeSelfPrefix = "postgres";
    user = "wisp";
  } args.configArgs;

  volumes = {
    data = "/var/lib/postgresql";
  };

  volumeMounts = lib.mapAttrsToList (name: containerPath:
    containerLib.mkVolume {
      hostPath = "${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name}";
      inherit containerPath;
    }
  ) volumes;

in

# // onlyoffice {
#   inherit pkgs;
#   configArgs = onlyofficeArgs;
#   image = images.onlyoffice;
# }

{
  systemd.tmpfiles.rules =
  [
    "d ${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}"
      "750 ${configArgs.user} root -"
  ]
  ++ lib.mapAttrsToList (name: _:
        "d ${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name} 0750 ${configArgs.user} root -"
      ) volumes;

}
// containerLib.mkContainerService {
  inherit image;
  name = "nextcloud${configArgs.nameSuffix}";
  # name = "nextcloud";
  environment = {
  };
  volumes = volumeMounts;

  # ports = [
  #   "8080:80"
  # ];
}
