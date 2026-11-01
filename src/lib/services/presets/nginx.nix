{
  pkgs,
  lib,
}: {
  name ? "nginx",
  postfix ? "",
  domain ? "",
  protocol ? "http",
  root ? "/mnt/nas",
  image ? "docker.io/library/nginx",
  tag ? "1.31",
  networks ? [],
  services ? [],
  httpPort ? 80,
  httpsPort ? 443,
  tlsDir ? "/mnt/nas/tls",
  sopsFile ? null,
  templateVars ? {},
}: let
  mk = import ../mk.nix {inherit pkgs lib;};
  mkVolume = import ../mkVolume.nix;
  mkHealthcheck = import ../mkHealthcheck.nix;

  fullName = "${name}${postfix}";
  vhosts = lib.concatMap (service: lib.toList (service.proxySnippet or [])) services;

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
    dir = ../../../services/nginx;
    baseImage = "${image}:${tag}";
    configMount = "/etc/nginx";
    templateVars = templateVars // {inherit vhosts protocol domain;};
    volumes = [
      (mkVolume {
        hostPath = tlsDir;
        containerPath = "/etc/nginx/tls";
        readOnly = true;
        create = false;
      })
      (mkVolume {
        hostPath = "/etc/localtime";
        containerPath = "/etc/localtime";
        readOnly = true;
        create = false;
      })
    ];
    ports = [
      "${toString httpPort}:80"
      "${toString httpsPort}:443"
    ];
    healthcheck = mkHealthcheck {
      cmd = "nginx -t";
      interval = "30s";
      timeout = "5s";
      retries = 3;
      startPeriod = "10s";
    };
  };
in {
  inherit name fullName vhosts;
  inherit (service) module config compose networks ports image;
  proxySnippet = [];
}
