{
  pkgs,
  lib,
}: {
  name ? "authentik",
  postfix ? "",
  domain ? "",
  protocol ? "http",
  root ? "/mnt/nas",
  image ? "ghcr.io/goauthentik/server",
  tag ? "2026.8.1",
  networks ? [],
  port ? null,
  postgres ? {
    host = "postgres";
    port = 5432;
  },
  sopsFile ? null,
  templateVars ? {},
}: let
  mk = import ../mk.nix {inherit pkgs lib;};
  mkVolume = import ../mkVolume.nix;
  mkHealthcheck = import ../mkHealthcheck.nix;

  fullName = "${name}${postfix}";
  postgresHost = postgres.host or "postgres";
  postgresPort = postgres.port or 5432;

  sharedSecrets = {
    AUTHENTIK_POSTGRESQL__PASSWORD = {
      sopsName = "services/${fullName}/db/db_password";
      owner = "1000";
      group = "1000";
      mode = "0400";
    };
    AUTHENTIK_POSTGRESQL__USER = {
      sopsName = "services/${fullName}/db/db_user";
      owner = "1000";
      group = "1000";
      mode = "0400";
    };
    AUTHENTIK_POSTGRESQL__NAME = {
      sopsName = "services/${fullName}/db/db_table";
      owner = "1000";
      group = "1000";
      mode = "0400";
    };
    AUTHENTIK_SECRET_KEY = {
      sopsName = "services/${fullName}/service/secret_key";
      owner = "1000";
      group = "1000";
      mode = "0400";
    };
  };

  commonEnvironment = {
    AUTHENTIK_POSTGRESQL__HOST = postgresHost;
    AUTHENTIK_POSTGRESQL__PORT = toString postgresPort;
  };

  server = mk {
    inherit
      name
      postfix
      domain
      protocol
      root
      networks
      sopsFile
      ;
    dir = ../../../services/authentik;
    dockerfile = "Dockerfile.server";
    baseImage = "${image}:${tag}";
    templateVars =
      templateVars
      // {
        inherit postgresHost postgresPort;
        postgres_host = postgresHost;
        postgres_port = postgresPort;
      };
    environment = commonEnvironment;
    secrets = sharedSecrets;
    volumes = [
      (mkVolume {
        hostPath = "${root}/${fullName}/data";
        containerPath = "/data";
        owner = "1000";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/custom-templates";
        containerPath = "/templates";
        owner = "1000";
      })
    ];
    ports = lib.optional (port != null) "${toString port}:9000";
    healthcheck = mkHealthcheck {
      cmd = "ak healthcheck server";
      interval = "30s";
      timeout = "30s";
      retries = 5;
      startPeriod = "90s";
    };
    shmSize = "512mb";
    dependsOn = [postgresHost];
  };

  worker = mk {
    name = "${name}-worker";
    inherit
      postfix
      domain
      protocol
      root
      networks
      sopsFile
      ;
    dir = ../../../services/authentik;
    dockerfile = "Dockerfile.worker";
    baseImage = "${image}:${tag}";
    templateVars =
      templateVars
      // {
        inherit postgresHost postgresPort;
        postgres_host = postgresHost;
        postgres_port = postgresPort;
      };
    environment = commonEnvironment;
    secrets = sharedSecrets;
    volumes = [
      (mkVolume {
        hostPath = "${root}/${fullName}/data";
        containerPath = "/data";
        owner = "1000";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/certs";
        containerPath = "/certs";
        owner = "1000";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/custom-templates";
        containerPath = "/templates";
        owner = "1000";
      })
    ];
    healthcheck = mkHealthcheck {
      cmd = "ak healthcheck worker";
      interval = "30s";
      timeout = "30s";
      retries = 5;
      startPeriod = "90s";
    };
    shmSize = "512mb";
    dependsOn = [postgresHost];
  };

  proxySnippet = ''
    server {
      listen 80;
      server_name ${fullName}.${domain};
      client_max_body_size 512m;
      location / {
        proxy_pass http://${fullName}:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      }
    }
  '';
in {
  inherit name fullName proxySnippet;
  module = {
    imports = [server.module worker.module];
  };
  config = server.config // worker.config;
  inherit (server) compose;
  networks = lib.unique (server.networks ++ worker.networks);
  ports = server.ports ++ worker.ports;
  inherit (server) image;
}
