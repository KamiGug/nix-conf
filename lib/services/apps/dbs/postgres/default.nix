{pkgs, ...} :
{
  configArgs ? {},
  image ? "docker.io/library/postgres:18.6",
}@args:

let
  lib = pkgs.lib;
  containerLib = import ../../.. {inherit pkgs;};
  validators = import ../../../../validators;

  configArgs = lib.recursiveUpdate {
    # protocol = "http";
    nameSuffix = "";
    volumePrefix = "/mnt/nas";
    volumeSelfPrefix = "postgres";
    serviceUser = "wisp";
    networks = [];
  } args.configArgs;
  name = "postgres${configArgs.nameSuffix}";
  inherit (configArgs) networks serviceUser;
  volumes = {
    data = "/var/lib/postgresql";
  };

  volumeMounts = lib.mapAttrsToList (name: containerPath:
    containerLib.mkVolume {
      hostPath = "${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name}";
      owner = configArgs.serviceUser;
      inherit containerPath;
    }
  ) volumes;

in

# {
#   systemd.tmpfiles.rules =
#   [
#     "d ${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix} 750 ${configArgs.serviceUser} root -"
#   ]
#   ++ lib.mapAttrsToList (name: _:
#         "d ${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name} 0750 ${configArgs.serviceUser} root -"
#       ) volumes;

# }
# //
containerLib.mkContainerService {
  inherit image networks serviceUser name;
  environment = {
    POSTGRES_USER = "postgres";
    POSTGRES_PASSWORD = "changeMe";
    POSTGRES_DB = "postgres";
  };
  volumes = volumeMounts;
  # ports = [
  #   "8080:80"
  # ];
}
