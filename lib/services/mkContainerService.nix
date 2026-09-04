{pkgs, ...}: {
  name,
  image,
  autoStart ? true,
  restart ? "on-failure",
  gpu ? false,
  privileged ? false,
  hostname ? null,
  serviceUser ? "root",
  containerUser ? null,
  volumes ? [],
  ports ? [],
  networks ? [],
  environment ? {},
  secrets ? [],
  labels ? {},
  command ? [],
  entrypoint ? null,
  dependencies ? [],
  healthcheck ? null,
  extraOptions ? [],
}: let
  inherit (pkgs) lib;
  myLib = {
    ensureDirExists = import ../ensureDirExists.nix;
  };

  volumeToString = v:
    "${v.hostMount}:${v.containerMount}"
    + lib.optionalString v.readOnly ":ro";

  networkNames =
    map
    (
      n:
        if builtins.isString n
        then n
        else n.name
    )
    networks;

  gpuOptions =
    if !gpu
    then []
    else [
      "--device=nvidia.com/gpu=all"
    ];

  secretOptions =
    map
    (s: "--secret=${s.path}")
    secrets;

  commandOptions = lib.optionalAttrs (command != []) {
    cmd = command;
  };

  entrypointOptions = lib.optionalAttrs (entrypoint != null) {
    inherit entrypoint;
  };

  healthOptions =
    lib.optionals (healthcheck != null)
    [
      "--health-cmd=${healthcheck.cmd}"
      "--health-interval=${healthcheck.interval}"
      "--health-timeout=${healthcheck.timeout}"
      "--health-retries=${toString healthcheck.retries}"
      "--health-start-period=${healthcheck.startPeriod}"
    ];
in
  assert builtins.isString name || throw "Container name must be a string";
  assert builtins.isString image || throw "Image name must be a string";
  assert builtins.isBool autoStart || throw "autoStart must be a boolean";
  assert builtins.isString restart || throw "restart must be a string";
  assert builtins.isBool gpu || throw "gpu must be a boolean";
  assert builtins.isBool privileged || throw "privileged must be a boolean";
  assert hostname
  == null
  || builtins.isString hostname
  || throw "hostname must be a string or null";
  assert builtins.isString serviceUser || throw "serviceUser must be a string";
  assert containerUser
  == null
  || builtins.isString containerUser
  || throw "containerUser must be a string or null";
  assert builtins.isList volumes || throw "volumes must be a list";
  assert builtins.isList ports || throw "ports must be a list";
  assert builtins.isList networks || throw "networks must be a list";
  assert builtins.isList secrets || throw "secrets must be a list";
  assert builtins.isList dependencies || throw "dependencies must be a list";
  assert builtins.isList extraOptions || throw "extraOptions must be a list";
  assert builtins.isList command || throw "command must be a list";
  assert builtins.isAttrs environment || throw "environment must be an attrset";
  assert builtins.isAttrs labels || throw "labels must be an attrset";
  assert entrypoint
  == null
  || builtins.isString entrypoint
  || throw "entrypoint must be a string or null";
  assert healthcheck
  == null
  || builtins.isAttrs healthcheck
  || throw "healthcheck must be an attrset";
  assert builtins.elem restart [
    "no"
    "on-success"
    "on-failure"
    "on-abnormal"
    "on-abort"
    "on-watchdog"
    "always"
  ]
  || throw "Invalid restart policy: ${restart}";
  assert lib.all (
    v:
      builtins.isAttrs v
      && v ? hostMount
      && v ? containerMount
      && v ? readOnly
      && v ? create
  )
  volumes
  || throw "Each volume must contain hostMount, containerMount, readOnly and create"; (lib.recursiveUpdate
    {
      virtualisation.oci-containers.backend = "podman";

      virtualisation.oci-containers.containers.${name} =
        {
          inherit
            image
            autoStart
            environment
            labels
            ports
            ;

          volumes =
            map volumeToString volumes;

          podman = {
            user = serviceUser;
            sdnotify =
              if healthcheck == null
              then "conmon"
              else "healthy";
          };

          extraOptions =
            gpuOptions
            ++ secretOptions
            ++ extraOptions
            ++ lib.optional privileged "--privileged"
            ++ lib.optional (hostname != null)
            "--hostname=${hostname}"
            ++ lib.optional (containerUser != null)
            "--user=${containerUser}"
            ++ healthOptions
            ++ map
            (n: "--network=${n}")
            networkNames;
          dependsOn = dependencies;
        }
        // commandOptions
        // entrypointOptions;
    }
    (lib.foldl'
      lib.recursiveUpdate
      {}
      (
        map (
          volume:
            if volume.create
            then
              myLib.ensureDirExists {
                inherit lib;
                path = volume.hostMount;
                inherit (volume) owner group mode;
                parentServiceName = name;
              }
            else {}
        )
        volumes
      )))
