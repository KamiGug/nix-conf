{pkgs, ...}: {
  configArgs ? {},
  image ? "ghcr.io/goauthentik/server:2026.8.1",
} @ args: let
  inherit (pkgs) lib;
  containerLib = import ../.. {inherit pkgs;};
  configArgs =
    lib.recursiveUpdate {
      nameSuffix = "";
      volumePrefix = "/mnt/nas";
      volumeSelfPrefix = "authentik";
      serviceUser = "root";
      containerUser = null;
      networks = [];
      postgres = {
        host = "postgres";
        port = 5432;
        database = "authentik";
        user = "authentik";
      };
      ports = {
        http = 9000;
        https = 9443;
      };
    }
    args.configArgs;
  name = "authentik-server${configArgs.nameSuffix}";
  inherit (configArgs) networks serviceUser containerUser;
  volumes = {
    data = "/data";
    templates = "/templates";
  };
  volumeMounts = lib.mapAttrsToList (name: containerPath:
    containerLib.mkVolume {
      hostPath = "${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name}";
      inherit containerPath;
      owner = configArgs.serviceUser;
    })
  volumes;
in
  containerLib.mkContainerService {
    inherit image networks serviceUser containerUser name;
    command = ["server"];
    # environment = {
    #   AUTHENTIK_POSTGRESQL__HOST = configArgs.postgres.host;
    #   AUTHENTIK_POSTGRESQL__PORT = toString configArgs.postgres.port;
    #   AUTHENTIK_POSTGRESQL__NAME = configArgs.postgres.database;
    #   AUTHENTIK_POSTGRESQL__USER = configArgs.postgres.user;
    # };
    volumes = volumeMounts;
    # ports = ["${toString configArgs.ports.http}:9000" "${toString configArgs.ports.https}:9443"];
    shmSize = "512mb";
  }
