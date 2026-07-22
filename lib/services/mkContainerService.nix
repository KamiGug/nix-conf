{
  pkgs,
  ...
}:

{
  name,
  image ? throw "Container ${name}: image is required",

  backend ? "podman",

  autoStart ? true,
  restart ? "on-failure",

  gpu ? false,
  privileged ? false,

  hostname ? null,
  user ? null,

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
    else if backend == "docker"
    then [
      "--gpus=all"
    ]
    else [
      "--device=nvidia.com/gpu=all"
    ];


  secretOptions =
    map
      (s: "--secret=${s.path}")
      secrets;


  healthcheckScript =
    if healthcheck == null
    then null
    else pkgs.writeShellScript "${name}-healthcheck" ''
      set -euo pipefail

      ${healthcheck.cmd}
    '';


  commandOptions =
    lib.optionalAttrs (command != []) {
      cmd = command;
    };


  entrypointOptions =
    lib.optionalAttrs (entrypoint != null) {
      inherit entrypoint;
    };


  healthOptions =
    lib.optionalAttrs (healthcheck != null) {
      serviceConfig = {
        ExecStartPost =
          "${healthcheckScript}";
      };
    };


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
  virtualisation.oci-containers.backend =
    backend;

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

      extraOptions =
        gpuOptions
        ++ secretOptions
        ++ extraOptions
        ++ lib.optional privileged "--privileged"
        ++ lib.optional (hostname != null)
          "--hostname=${hostname}"
        ++ lib.optional (user != null)
          "--user=${user}"
        ++ map
          (n: "--network=${n}")
          networkNames;
      dependsOn = dependencies;
  }
  // commandOptions
  // entrypointOptions;
  # //
  # {
    # systemd.services."${backend}-${name}" = {
    #   after = lib.mkAfter (map (d: "${d}.service") dependencies);
    #   requires = lib.mkAfter (map (d: "${d}.service") dependencies);
    #   Restart = restart;
    # };
  # };
}
