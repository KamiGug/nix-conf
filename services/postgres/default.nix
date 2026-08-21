{
  pkgs,
  config,
  lib,
  myLib,
  ...
}:

let
  cfg = config.services.my.postgres;
  # domain =
  #   if cfg.configArgs ? domain
  #   then cfg.configArgs.domain
  #   else "file.${cfg.configArgs.rootDomain}";

in
{
  options.services.my.postgres = {

    enable = lib.mkEnableOption "Run postgres database";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/postgres:18.4";
    };

    volumePrefix = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nas/";
    };

    selfPrefix = lib.mkOption {
      type = lib.types.str;
      default = "postgres";
    };

    configArgs = lib.mkOption {
      type = lib.types.attrs;
      default = {
        protocol = "http";
        rootDomain = "arpa";
      };
    };

    namePrefix = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    nameSuffix = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };


  config = lib.mkIf cfg.enable ({
      # TODO: ensure each dir exists
    } //
    myLib.serv.mkContainerService {

      inherit (cfg) image;

      name =
        "${cfg.namePrefix}nextcloud${cfg.nameSuffix}";

      environment = {

      };

      volumes = [
        (myLib.serv.mkVolume {
          hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/data";
          containerPath = "/var/www/html/data";
        })

# /docker-entrypoint-initdb.d

        # (myLib.serv.mkVolume {
        #   hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/config";
        #   containerPath = "/var/www/html/config";
        # })
        # (myLib.serv.mkVolume {
        #   hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/apps";
        #   containerPath = "/var/www/html/apps";
        # })
        # (myLib.serv.mkVolume {
        #   hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/custom_apps";
        #   containerPath = "/var/www/html/custom_apps";
        # })
      ];


      # TODO:
      # remove when reverse proxy is added
      ports = [
        "8080:80"
      ];
    });
}
