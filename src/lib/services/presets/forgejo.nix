{
  pkgs,
  lib,
}: {
  name ? "forgejo",
  postfix ? "",
  domain ? "",
  protocol ? "http",
  root ? "/mnt/nas",
  image ? "codeberg.org/forgejo/forgejo",
  tag ? "16",
  networks ? [],
  port ? null,
  sshPort ? null,
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
  secretVar = "FORGEJO__database__PASSWD";

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
    dir = ../../../services/forgejo;
    baseImage = "${image}:${tag}";
    templateVars =
      templateVars
      // {
        inherit postgresHost postgresPort;
        postgres_host = postgresHost;
        postgres_port = postgresPort;
      };
    environment = {
      FORGEJO__server__SSH_DOMAIN = "${fullName}.${domain}";
      FORGEJO__server__ROOT_URL = "${protocol}://${fullName}.${domain}";
      FORGEJO__database__DB_TYPE = "postgres";
      FORGEJO__database__HOST = "${postgresHost}:${toString postgresPort}";
      FORGEJO__service__DEFAULT_USER_VISIBILITY = "limited";
      FORGEJO__service__ALLOWED_USER_VISIBILITY_MODES = "limited";
      FORGEJO__service__DEFAULT_ORG_VISIBILITY = "limited";
      FORGEJO__service__DEFAULT_ORG_MEMBER_VISIBLE = "true";
      FORGEJO__repository__DEFAULT_BRANCH = "master";
    };
    secrets = {
      ${secretVar} = {
        sopsName = "services/${fullName}/db/db_password";
      };
      FORGEJO__database__USER = {
        sopsName = "services/${fullName}/db/db_user";
      };
      FORGEJO__database__NAME = {
        sopsName = "services/${fullName}/db/db_table";
      };
    };
    volumes = [
      (mkVolume {
        hostPath = "${root}/${fullName}/data";
        containerPath = "/data";
        owner = "1000";
      })
      (mkVolume {
        hostPath = "/etc/localtime";
        containerPath = "/etc/localtime";
        readOnly = true;
        create = false;
      })
    ];
    ports =
      lib.optional (port != null) "${toString port}:3000"
      ++ lib.optional (sshPort != null) "${toString sshPort}:${toString sshPort}";
    healthcheck = mkHealthcheck {
      cmd = "curl -fsS http://localhost:3000/api/healthz || exit 1";
      interval = "30s";
      timeout = "10s";
      retries = 5;
      startPeriod = "60s";
    };
    dependsOn = [postgresHost];
  };

  proxySnippet = ''
    server {
      listen 80;
      server_name ${fullName}.${domain};
      client_max_body_size 512m;
      location / {
        proxy_pass http://${fullName}:3000;
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
