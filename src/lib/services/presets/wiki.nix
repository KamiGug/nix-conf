{
  pkgs,
  lib,
}: {
  name ? "wiki",
  postfix ? "",
  domain ? "",
  protocol ? "http",
  root ? "/mnt/nas",
  image ? "docker.io/library/mediawiki",
  tag ? "1.43",
  networks ? [],
  port ? null,
  postgres ? {
    host = "postgres";
    port = 5432;
  },
  sitename ? null,
  lang ? "en",
  adminUser ? "Admin",
  adminPasswordSecret ? "services/${name}${postfix}/service/root_password",
  oidc ? {},
  sopsFile ? null,
  templateVars ? {},
}: let
  mk = import ../mk.nix {inherit pkgs lib;};
  mkVolume = import ../mkVolume.nix;
  mkHealthcheck = import ../mkHealthcheck.nix;
  render = import ../render.nix {inherit pkgs lib;};

  fullName = "${name}${postfix}";
  postgresHost = postgres.host or "postgres";
  postgresPort = postgres.port or 5432;
  effectiveSitename =
    if sitename != null
    then sitename
    else fullName;

  tagParts = lib.splitString "." tag;
  mediawikiBranch = "REL${lib.head tagParts}_${lib.elemAt tagParts 1}";

  setup = render {
    template = ../../../services/wiki/templates/setup.sh.jinja;
    vars = {};
    name = "setup.sh";
  };

  baseSecrets = {
    MW_DB_PASSWORD = {
      sopsName = "services/${fullName}/db/db_password";
    };
    MW_DB_USER = {
      sopsName = "services/${fullName}/db/db_user";
    };
    MW_DB_NAME = {
      sopsName = "services/${fullName}/db/db_table";
    };
  };

  adminSecrets = lib.optionalAttrs (adminPasswordSecret != null) {
    MW_ADMIN_PASSWORD = {
      sopsName = adminPasswordSecret;
    };
  };

  oidcSecrets = lib.optionalAttrs ((oidc.enable or false) && oidc ? clientSecretSopsName) {
    MW_OIDC_CLIENT_SECRET = {
      sopsName = oidc.clientSecretSopsName;
    };
  };

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
    dir = ../../../services/wiki;
    baseImage = "${image}:${tag}";
    buildArgs = {MEDIAWIKI_BRANCH = mediawikiBranch;};
    buildFiles = {"setup.sh" = "${setup}/setup.sh";};
    configMount = "/etc/mediawiki";
    templateVars =
      templateVars
      // {
        inherit lang oidc;
        sitename = effectiveSitename;
      };
    environment = {
      MW_CONFIG_FILE = "/etc/mediawiki/LocalSettings.php";
      MW_DB_TYPE = "postgres";
      MW_DB_HOST = postgresHost;
      MW_DB_PORT = toString postgresPort;
      MW_DB_SCHEMA = "mediawiki";
      MW_SITENAME = effectiveSitename;
      MW_LANG = lang;
      MW_ADMIN_USER = adminUser;
    };
    secrets = baseSecrets // adminSecrets // oidcSecrets;
    volumes = [
      (mkVolume {
        hostPath = "${root}/${fullName}/images";
        containerPath = "/var/www/html/images";
        owner = "33";
      })
      (mkVolume {
        hostPath = "${root}/${fullName}/data";
        containerPath = "/var/lib/mediawiki";
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
      cmd = "curl -fsS -o /dev/null 'http://localhost/index.php?title=Special:Version' || exit 1";
      interval = "30s";
      timeout = "10s";
      retries = 5;
      startPeriod = "600s";
    };
    dependsOn = [postgresHost];
  };

  proxySnippet = ''
    server {
      listen 80;
      server_name ${fullName}.${domain};
      client_max_body_size 512m;
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
