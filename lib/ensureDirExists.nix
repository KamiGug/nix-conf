{
  lib,
  path,
  parentServiceName ? null,
  owner ? null,
  group ? null,
  mode ? null,
}: let
  serviceName = lib.replaceStrings ["/"] ["@"] path;
  calculatedMode =
    if mode != null then mode
    else if group != null then "0770"
    else "0700";

in {
  systemd.services."EnsureDir-${serviceName}" = {
    description = "Ensure directory ${path} exists";

    before = lib.mkIf (parentServiceName != null) [
      "${parentServiceName}.service"
    ];

    requiredBy = lib.mkIf (parentServiceName != null) [
      "${parentServiceName}.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      if [ ! -d "${path}" ]; then
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
