{
  pkgs,
  lib,
  ...
}: {
  postfix ? "",
  domain ? "",
  root ? "/mnt/nas",
  backend ? "podman",
  sopsFile ? null,
  networks ? [],
  services ? [],
  templateVars ? {},
}: let
  ensureNetwork = import ./ensureNetwork.nix {inherit pkgs;};

  allNetworks = lib.unique (
    networks
    ++ lib.concatMap (service: service.networks or []) services
  );

  networkUnit = n: "ensure-${n}${postfix}-${backend}-network-exists";

  networkModules = map (n:
    ensureNetwork {
      name = n;
      inherit postfix backend;
    })
  allNetworks;

  containerNames = map (service: service.fullName or service.name) services;

  orderModule = {
    systemd.services = builtins.listToAttrs (map (n: {
        name = networkUnit n;
        value.before = map (container: "podman-${container}.service") containerNames;
      })
      allNetworks);
  };

  hostPortOf = port: let
    parts = lib.splitString ":" port;
    count = builtins.length parts;
  in
    if count >= 2
    then lib.elemAt parts (count - 2)
    else null;

  portEntries = lib.concatMap (service:
    map (port: {
      inherit port;
      service = service.fullName or service.name;
    }) (builtins.filter (port: hostPortOf port != null) (service.ports or [])))
  services;

  portCounts =
    lib.foldl'
    (acc: entry: let
      hostPort = hostPortOf entry.port;
    in
      acc
      // {
        ${hostPort} = (acc.${hostPort} or []) ++ [entry.service];
      })
    {}
    portEntries;

  clashes = lib.filterAttrs (_: names: builtins.length names > 1) portCounts;

  portAssertion =
    if clashes == {}
    then true
    else throw "services claim the same host port: ${builtins.toJSON clashes}";
in
  assert portAssertion; {
    inherit
      networks
      allNetworks
      services
      domain
      root
      sopsFile
      templateVars
      ;
    module = {
      imports =
        networkModules
        ++ [orderModule]
        ++ map (service: service.module) services;
    };
  }
