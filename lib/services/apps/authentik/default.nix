{pkgs, ...}: {
  configArgs ? {},
  images ? {
    server = "ghcr.io/goauthentik/server:2026.8.1";
    worker = "ghcr.io/goauthentik/server:2026.8.1";
  },
}: let
  inherit (pkgs) lib;
  myLib.file = import ../../../file {inherit pkgs;};
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
    inherit (parsedConfigArgs) secretKeyPrefix postgres containerUser serviceUser volumePrefix nameSuffix;
  };
  serverArgs =
    commonArgs
    // {
      inherit (parsedConfigArgs) ports ;
      networks = parsedConfigArgs.networks.server;
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
      (myLib.file.ensureDirExists {
        path = "/etc/authentik";
      })
      (myLib.file.mkRandomSecret {
        path = "/etc/authentik/${serverArgs.secretKeyPrefix}secret";
        # TODO: make service name generators serparate functions for each service creating function/modules
        parentServiceName = "EnsureDirExists-@etc@authentik";
      })
      (authentikServer {
        configArgs = serverArgs;
        image = images.server;
      })
      (authentikWorker {
        configArgs = workerArgs;
        image = images.worker;
      })
    ]
