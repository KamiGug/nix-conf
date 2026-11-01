{
  pkgs,
  lib,
}: {
  name ? "nextcloud",
  postfix ? "",
  domain ? "",
  protocol ? "http",
  root ? "/mnt/nas",
  image ? "docker.io/library/nextcloud",
  tag ? "32",
  networks ? [],
  port ? null,
  postgres ? {
    host = "postgres";
    port = 5432;
  },
  trustedProxies ? null,
  sopsFile ? null,
  templateVars ? {},
}: let
  mk = import ../mk.nix {inherit pkgs lib;};
  mkVolume = import ../mkVolume.nix;
  mkHealthcheck = import ../mkHealthcheck.nix;

  fullName = "${name}${postfix}";
  postgresHost = postgres.host or "postgres";
  postgresPort = postgres.port or 5432;

  service = mk {
    inherit
      name
      postfix
      domain
      protocol
      root
      networks
      sopsFile
      ;
    dir = ../../../services/nextcloud;
    baseImage = "${image}:${tag}";
    templateVars =
      templateVars
      // {
        inherit postgresHost postgresPort;
        postgres_host = postgresHost;
        postgres_port = postgresPort;
      };
    environment =
      {
        NEXTCLOUD_TRUSTED_DOMAINS = "${fullName}.${domain} ${fullName}";
        overwriteprotocol = protocol;
        overwritehost = "${fullName}.${domain}";
        "overwrite.cli.url" = "${protocol}://${fullName}.${domain}";
        POSTGRES_HOST = "${postgresHost}:${toString postgresPort}";
      }
      // lib.optionalAttrs (trustedProxies != null) {
        NEXTCLOUD_TRUSTED_PROXIES = trustedProxies;
      };
    secrets = {
      POSTGRES_PASSWORD = {
        sopsName = "services/${fullName}/db/db_password";
      };
      POSTGRES_USER = {
        sopsName = "services/${fullName}/db/db_user";
      };
      POSTGRES_DB = {
        sopsName = "services/${fullName}/db/db_table";
      };
    };
    volumes = [
      (mkVolume {
        hostPath = "${root}/${fullName}/data";
        containerPath = "/var/www/html/data";
        owner = "33";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/apps";
        containerPath = "/var/www/html/apps";
        owner = "33";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/custom-apps";
        containerPath = "/var/www/html/custom_apps";
        owner = "33";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/config";
        containerPath = "/var/www/html/config";
        owner = "33";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/application";
        containerPath = "/var/www/html";
        owner = "33";
      })
      (mkVolume {
        hostPath = "/etc/localtime";
        containerPath = "/etc/localtime";
        readOnly = true;
        create = false;
      })
    ];
    ports = lib.optional (port != null) "${toString port}:80";
    healthcheck = mkHealthcheck {
      cmd = "curl -fsS http://localhost/status.php || exit 1";
      interval = "30s";
      timeout = "10s";
      retries = 5;
      startPeriod = "120s";
    };
    dependsOn = [postgresHost];
  };

  proxySnippet = ''
    server {
      listen 80;
      server_name ${fullName}.${domain};
      client_max_body_size 10g;
      location / {
        proxy_pass http://${fullName}:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
  '';
in {
  inherit name fullName proxySnippet;
  inherit (service) module config compose networks ports image;
}
