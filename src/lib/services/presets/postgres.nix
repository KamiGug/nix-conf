{
  pkgs,
  lib,
}: {
  name ? "postgres",
  postfix ? "",
  domain ? null,
  protocol ? null,
  root ? "/mnt/nas",
  image ? "docker.io/library/postgres",
  tag ? "18.6",
  networks ? [],
  user ? "postgres",
  port ? null,
  databases ? {},
  sopsFile ? null,
  templateVars ? {},
  dataOwner ? "999",
}: let
  mk = import ../mk.nix {inherit pkgs lib;};
  mkVolume = import ../mkVolume.nix;
  mkHealthcheck = import ../mkHealthcheck.nix;

  fullName = "${name}${postfix}";

  major = lib.toInt (lib.head (lib.splitString "." (lib.head (lib.splitString "-" tag))));
  dataContainerPath =
    if major < 18
    then "/var/lib/postgresql/data"
    else "/var/lib/postgresql";

  superSecretName = "services/${fullName}/service/root_password";
  superSecretPath = "/run/secrets/${superSecretName}";
  superUserSecretName = "services/${fullName}/service/root_user";
  superUserPath = "/run/secrets/${superUserSecretName}";

  databaseList =
    lib.mapAttrsToList (db: cfg: let
      prefix = lib.replaceStrings ["-"] ["_"] db;
      nameVar = "${prefix}_name";
      userVar = "${prefix}_user";
      var = cfg.var or "${prefix}_pass";
      nameSopsName = cfg.nameSopsName or "services/${db}/db/db_table";
      userSopsName = cfg.userSopsName or "services/${db}/db/db_user";
      passSopsName = cfg.sopsName or "services/${db}/db/db_password";
      namePath = cfg.namePath or "/run/secrets/${nameSopsName}";
      userPath = cfg.userPath or "/run/secrets/${userSopsName}";
      secretPath = cfg.secretPath or "/run/secrets/${passSopsName}";
    in {
      name = db;
      inherit
        nameVar
        userVar
        var
        namePath
        userPath
        secretPath
        ;
    })
    databases;

  databaseSqlVars =
    map (db: {
      inherit (db) name nameVar userVar var;
    })
    databaseList;

  initVars = lib.concatMapStringsSep " " (db:
    "-v ${db.nameVar}=\"$(cat ${db.namePath})\" "
    + "-v ${db.userVar}=\"$(cat ${db.userPath})\" "
    + "-v ${db.var}=\"$(cat ${db.secretPath})\"")
  databaseList;

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
    dir = ../../../services/postgres;
    baseImage = "${image}:${tag}";
    templateVars =
      templateVars
      // {
        inherit dataContainerPath;
        postgres_user = user;
        databases = databaseSqlVars;
      };
    environment = {
      POSTGRES_DB = "postgres";
    };
    secrets = {
      POSTGRES_USER = {
        sopsName = superUserSecretName;
      };
      POSTGRES_PASSWORD = {
        sopsName = superSecretName;
      };
    };
    volumes = [
      (mkVolume {
        hostPath = "${root}/${fullName}/data";
        containerPath = dataContainerPath;
        owner = dataOwner;
        mode = "0700";
      })
      (mkVolume {
        hostPath = "/etc/localtime";
        containerPath = "/etc/localtime";
        readOnly = true;
        create = false;
      })
    ];
    ports = lib.optional (port != null) "${toString port}:5432";
    healthcheck = mkHealthcheck {
      cmd = "pg_isready -U \"$(cat ${builtins.dirOf superUserPath}/POSTGRES_USER)\" -d postgres";
      interval = "5s";
      timeout = "5s";
      retries = 5;
      startPeriod = "10s";
    };
  };

  initScript = ''
    set -euo pipefail

    superuser="$(cat ${superUserPath})"

    until ${pkgs.podman}/bin/podman exec ${fullName} pg_isready -U "$superuser" -d postgres >/dev/null 2>&1; do
      sleep 1
    done

    ${pkgs.podman}/bin/podman exec -i ${fullName} \
      env PGPASSWORD="$(cat ${superSecretPath})" \
      psql -v ON_ERROR_STOP=1 -U "$superuser" -d postgres \
      ${initVars} \
      -f ${service.config."init.sql.jinja"}/init.sql
  '';

  initModule = {
    systemd.services."init-${fullName}" = {
      description = "Initialise databases in ${fullName}";
      wantedBy = ["multi-user.target"];
      after = ["podman-${fullName}.service" "sops-install-secrets.service"];
      wants = ["podman-${fullName}.service" "sops-install-secrets.service"];
      requires = ["sops-install-secrets.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = initScript;
    };
  };
in {
  inherit name fullName;
  inherit (service) config compose networks ports image;
  module = {
    imports = [service.module initModule];
  };
}
