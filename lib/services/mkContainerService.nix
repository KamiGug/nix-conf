{
  pkgs,
  ...
}:

{
  name,
  image ? throw "Container ${name}: image is required",
  backend ? "podman",
  autoStart ? true,
  restart ? "unless-stopped",
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
  command ? null,
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


  portToString = p:
    "${toString p.host}:${toString p.container}/${p.protocol}";


  networkNames =
    map (n:
      if builtins.isString n
      then n
      else n.name
    ) networks;


  gpuOptions =
    if !gpu
    then []
    else
      if backend == "docker"
      then [ "--gpus=all" ]
      else [ "--device=nvidia.com/gpu=all" ];


  secretOptions =
    map (s:
      "--secret=${s.path}"
    ) secrets;

in
{

  virtualisation.oci-containers.backend =
    backend;


  virtualisation.oci-containers.containers.${name} = {
    inherit
      image
      autoStart
      environment
      labels
      ;

    volumes =
      map volumeToString volumes;

    ports =
      map portToString ports;


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


    cmd =
      command;

    entrypoint =
      entrypoint;
  };


  systemd.services.${name} = {

    after =
      map
        (d: "${d}.service")
        dependencies;


    requires =
      map
        (d: "${d}.service")
        dependencies;

    serviceConfig = {
      Restart = restart;
    };
  };
}
