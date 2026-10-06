{pkgs, ...}@args:
{
  path,
  parentServiceName ? null,
  owner ? null,
  group ? null,
  mode ? null,
}: let
  inherit (pkgs) lib;
  serviceName = lib.replaceStrings ["/"] ["@"] path;
  calculatedMode =
    if mode != null
    then mode
    else if group != null
    then "0770"
    else "0700";
in {
  systemd.services."EnsureDir-${serviceName}" = {
    description = "Ensure directory ${path} exists";

    before = if (builtins.isString parentServiceName) then
        [ "${parentServiceName}.service" ]
      # else if (builtins.isList parentServiceName) then
      #   parentServiceName
      else
        [];

    requiredBy = if (builtins.isString parentServiceName) then
        [ "${parentServiceName}.service" ]
      # else if (builtins.isList parentServiceName) then
      #   parentServiceName
      else
        [];

    wantedBy = [
      "multi-user.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      if [ ! -d "${path}" ]; then
        echo "creating directory ${path}"
        mkdir -p "${path}"
        ${lib.optionalString (owner != null) ''
        chown "${owner}" "${path}"
      ''}
        ${lib.optionalString (group != null) ''
        chgrp "${group}" "${path}"
      ''}
        chmod "${calculatedMode}" "${path}"
      else
        echo "Dir ${path} already exists"
        ls -A -dhl "${path}"
      fi
    '';
  };
}
