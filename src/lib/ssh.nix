{lib, ...}: let
  numbered = prefix: list:
    lib.imap0 (i: value: {
      name =
        if i == 0
        then prefix
        else "${prefix}-${toString (i + 1)}";
      inherit value;
    })
    list;

  expandHost = key: defaults: host: let
    common = defaults // builtins.removeAttrs host ["names" "ips" "vpnIps" "host" "hostname"];

    names =
      if (host.names or []) == []
      then
        (
          if host ? hostname
          then [host.hostname]
          else [key]
        )
      else host.names;

    primary = builtins.head names;
    extraNames = builtins.tail names;
    ips = host.ips or [];
    vpnIps = host.vpnIps or [];

    entry = alias: hostname:
      {
        host = alias;
        inherit hostname;
      }
      // common;

    primaryEntry =
      lib.nameValuePair key (entry (host.host or primary) primary);

    extraNameEntries =
      lib.imap0 (i: name: lib.nameValuePair "${key}-${toString (i + 2)}" (entry name name))
      extraNames;

    ipEntries = map (item: lib.nameValuePair item.name (entry item.name item.value)) (numbered "${key}-lan" ips);
    vpnEntries = map (item: lib.nameValuePair item.name (entry item.name item.value)) (numbered "${key}-vpn" vpnIps);
  in
    [primaryEntry] ++ extraNameEntries ++ ipEntries ++ vpnEntries;
in {
  mkHosts = {
    defaults ? {},
    hosts,
  }: let
    entries = lib.concatLists (lib.mapAttrsToList (key: host: expandHost key defaults host) hosts);
  in
    builtins.listToAttrs entries;
}
