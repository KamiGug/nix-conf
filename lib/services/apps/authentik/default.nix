{pkgs, ...}: {
  configArgs ? {},
  images ? {
    server = "ghcr.io/goauthentik/server:2026.8.1";
    worker = "ghcr.io/goauthentik/server:2026.8.1";
  },
}: let
  inherit (pkgs) lib;
  myLib = {
    ensureDirExists = import ../../../file/ensureDirExists.nix;
  };
  authentikServer = import ./server.nix {inherit pkgs;};
  authentikWorker = import ./worker.nix {inherit pkgs;};
  parsedConfigArgs =
    lib.recursiveUpdate {
      nameSuffix = "";
      volumePrefix = "/mnt/nas";
      volumeSelfPrefix = "authentik";
      serviceUser = "root";
      secretKeyPrefix = "";
      containerUser = null;
      networks = {
        server = [];
        worker = [];
      };
      # postgres = {
      #   host = "postgres";
      #   port = 5432;
      #   database = "authentik";
      #   user = "authentik";
      # };
      # ports = {
      #   http = 9000;
      #   https = 9443;
      # };
    }
    configArgs;
  commonArgs = {
    inherit pkgs;
    nameSuffix = parsedConfigArgs.nameSuffix;
    volumePrefix = parsedConfigArgs.volumePrefix;
    serviceUser = parsedConfigArgs.serviceUser;
    containerUser = parsedConfigArgs.containerUser;
    postgres = parsedConfigArgs.postgres;
  };
  serverArgs =
    commonArgs
    // {
      networks = parsedConfigArgs.networks.server;
      ports = parsedConfigArgs.ports;
    };
  workerArgs =
    commonArgs
    // {
      networks = parsedConfigArgs.networks.worker;
    };
in
  assert images ? server;
  assert images ? worker;
    lib.foldl'
    lib.recursiveUpdate
    {}
    [
      (
        myLib.ensureDirExists {
          inherit lib;
          path = "/etc/authentik";
        }
      )

      (authentikServer {
        configArgs = serverArgs;
        image = images.server;
      })
      (authentikWorker {
        configArgs = workerArgs;
        image = images.worker;
      })
    ]
