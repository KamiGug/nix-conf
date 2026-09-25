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

      # postgres = {
      #   host = "postgres";
      #   port = 5432;
      #   database = "authentik";
      #   user = "authentik";
      # };
    }
    args.configArgs;

  name = "authentik-worker${configArgs.nameSuffix}";

  inherit
    (configArgs)
    networks
    serviceUser
    containerUser
    ;

  volumes = {
    data = "/data";
    templates = "/templates";
    certs = "/certs";
  };

  volumeMounts =
    (lib.mapAttrsToList (
      name: containerPath:
        containerLib.mkVolume {
          hostPath = "${configArgs.volumePrefix}/${configArgs.volumeSelfPrefix}/${name}";

          inherit containerPath;

          owner = configArgs.serviceUser;
        }
    )
    volumes)
    ++ [
      (containerLib.mkVolume {
        hostPath = "/etc/authentik/${configArgs.secretKeyPrefix}secret";
        containerPath = "/run/authentik/secret";
        owner = "1000";
      })
    ];
in
  containerLib.mkContainerService {
    inherit
      image
      networks
      serviceUser
      containerUser
      name
      ;

    command = ["worker"];

    environment = {
      AUTHENTIK_SECRET_KEY = "file:///run/authentik/secret";
    };

    volumes = volumeMounts;

    shmSize = "512mb";
  }
