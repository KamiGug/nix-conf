{
  lib,
  ...
}: {
  name,
  image,
  backend ? "podman",
  autoStart ? true,
  restart ? "on-failure",
  gpu ? false,
  privileged ? false,
  hostname ? null,
  serviceUser ? "root",
  containerUser ? null,
  volumes ? [],
  ports ? [],
  environment ? {},
  labels ? {},
  command ? [],
  entrypoint ? null,
  shmSize ? null,
  dependsOn ? [],
  healthcheck ? null,
  extraOptions ? [],
}: let
  volumeToString = v:
    if builtins.isString v
    then v
    else
      "${v.hostMount}:${v.containerMount}"
      + lib.optionalString (v.readOnly or false) ":ro";

  gpuOptions = lib.optional gpu "--device=nvidia.com/gpu=all";

  commandOptions = lib.optionalAttrs (command != []) {cmd = command;};
  entrypointOptions = lib.optionalAttrs (entrypoint != null) {inherit entrypoint;};

  healthOptions = lib.optionals (healthcheck != null) [
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
  assert builtins.elem backend ["docker" "podman"] || throw "backend must be either 'docker' or 'podman'";
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
      builtins.isString v
      || (builtins.isAttrs v && v ? hostMount && v ? containerMount)
  )
  volumes
  || throw "Each volume must be a string or contain hostMount and containerMount"; {
    virtualisation.oci-containers.backend = backend;
    virtualisation.oci-containers.containers.${name} =
      {
        inherit
          image
          autoStart
          environment
          labels
          ports
          ;

        volumes = map volumeToString volumes;

        podman = {
          user = serviceUser;
          sdnotify =
            if healthcheck == null
            then "conmon"
            else "healthy";
        };

        extraOptions =
          gpuOptions
          ++ extraOptions
          ++ lib.optional privileged "--privileged"
          ++ lib.optional (hostname != null) "--hostname=${hostname}"
          ++ lib.optional (containerUser != null) "--user=${containerUser}"
          ++ healthOptions
          ++ lib.optional (shmSize != null) "--shm-size=${shmSize}";
        inherit dependsOn;
      }
      // commandOptions
      // entrypointOptions;
  }
