{pkgs, ...}: {
  configArgs ? {},
  image ? "docker.io/library/postgres:18.6",
} @ args: let
  inherit (pkgs) lib;
  containerLib = import ../../.. {inherit pkgs;};

  configArgs =
    lib.recursiveUpdate {
      # protocol = "http";
      nameSuffix = "";
      volumePrefix = "/mnt/nas";
      volumeSelfPrefix = "postgres";
      serviceUser = "root";
      containerUser = "wisp";
      networks = [];
    }
    args.configArgs;
  name = "postgres${configArgs.nameSuffix}";
  inherit (configArgs) networks serviceUser containerUser;
  volumes = {
    data = "/var/lib/postgresql";
  };

  volumeMounts =
    lib.mapAttrsToList (
      name: containerPath:
        containerLib.mkVolume {
          hostPath = "${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name}";
          owner = configArgs.serviceUser;
          inherit containerPath;
        }
    )
    volumes;
in
  containerLib.mkContainerService {
    inherit image networks serviceUser containerUser name;
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
