{
  pkgs,
  config,
  lib,
  myLib,
  ...
}:

let
  cfg = config.services.my.nextcloud;

  domain =
    if cfg.configArgs ? domain
    then cfg.configArgs.domain
    else "file.${cfg.configArgs.rootDomain}";

    volumes = {
       data = "/var/www/html/data";
       config = "/var/www/html/config";
       apps = "/var/www/html/apps";
       custom_apps = "/var/www/html/custom_apps";
     };

     hostPaths = lib.mapAttrsToList (name: _:
       "${cfg.volumePrefix}/${cfg.selfPrefix}/${name}"
     ) volumes;

     volumeMounts = lib.mapAttrsToList (name: containerPath:
       myLib.serv.mkVolume {
         hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/${name}";
         inherit containerPath;
       }
     ) volumes;

in
{
  options.services.my.nextcloud = {

    enable = lib.mkEnableOption "Run a nextcloud service";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/nextcloud:31";
    };

    volumePrefix = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nas/";
    };

    selfPrefix = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud";
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

    user = lib.mkOption {
      type = lib.types.str;
      default = "wisp";
    };
  };


  config = lib.mkIf cfg.enable ({
    systemd.tmpfiles.rules =
      [
        "d /tmp 1777 root root 10d"

      ];
  } //
    myLib.serv.mkContainerService {

      inherit (cfg) image user;

      name =
        "${cfg.namePrefix}nextcloud${cfg.nameSuffix}";

      environment = {
        NEXTCLOUD_TRUSTED_DOMAINS = domain;

        serverName = "${cfg.configArgs.protocol}://${domain}";
      };

      volumes = [
        (myLib.serv.mkVolume {
          hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/data";
          containerPath = "/var/www/html/data";
        })
        (myLib.serv.mkVolume {
          hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/config";
          containerPath = "/var/www/html/config";
        })
        (myLib.serv.mkVolume {
          hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/apps";
          containerPath = "/var/www/html/apps";
        })
        (myLib.serv.mkVolume {
          hostPath = "${cfg.volumePrefix}/${cfg.selfPrefix}/custom_apps";
          containerPath = "/var/www/html/custom_apps";
        })
      ];


      # TODO:
      # remove when reverse proxy is added
      ports = [
        "8080:80"
      ];
    });
}
