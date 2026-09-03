{
  pkgs,
  ...
}:
# TODO: make this a user service
{
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
}:
assert builtins.isString image || throw "Image name must be a string";
let
  lib = pkgs.lib;

  volumeToString = v:
    "${v.hostMount}:${v.containerMount}"
    + lib.optionalString v.readOnly ":ro";

  networkNames =
    map
      (n:
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

  commandOptions =
    lib.optionalAttrs (command != []) {
      cmd = command;
    };


  entrypointOptions =
    lib.optionalAttrs (entrypoint != null) {
      inherit entrypoint;
    };


  healthOptions = lib.optionals (healthcheck != null)
  [
    "--health-cmd=${healthcheck.cmd}"
    "--health-interval=${healthcheck.interval}"
    "--health-timeout=${healthcheck.timeout}"
    "--health-retries=${toString healthcheck.retries}"
    "--health-start-period=${healthcheck.startPeriod}"
  ];

in

assert builtins.elem restart [
  "no"
  "on-success"
  "on-failure"
  "on-abnormal"
  "on-abort"
  "on-watchdog"
  "always"
];
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
        sdnotify = if healthcheck == null then "conmon" else "healthy" ;
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
