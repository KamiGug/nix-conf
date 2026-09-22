{pkgs, ...}: {
  path,
  contents ? "",
  parentServiceName ? null,
  owner ? null,
  group ? null,
  mode ? "0644",
  forceModeAndOwnership ? false,
}: let
  inherit (pkgs) lib;
  serviceName = lib.replaceStrings ["/"] ["@"] path;
in {
  systemd.services."GenerateFile-${serviceName}" = {
    description = "Generate file at ${path}";

    before =
      if (builtins.isString parentServiceName)
      then ["${parentServiceName}.service"]
      # else if (builtins.isList parentServiceName)
      # then parentServiceName
      else [];

    requiredBy =
      if (builtins.isString parentServiceName)
      then ["${parentServiceName}.service"]
      # else if (builtins.isList parentServiceName)
      # then parentServiceName
      else [];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail
      CREATED_THE_FILE=0
      if [[ ! -f "${path}" ]]; then
        if [[ -e "${path}" ]]; then
          echo "${path} already exists, and is not a regular file" >&2
          exit 1
        else
          CREATED_THE_FILE=1
          echo '${contents}' > "${path}"
        fi
      fi

      if [[ $CREATED_THE_FILE || ${if forceModeAndOwnership then "true" else "false"} ]]; then
        echo "setting owner ${if (owner != null) then owner else "null"}, group ${if (group != null) then group else "null"} and mode ${if (mode != null) then mode else "null"}"
        ${lib.optionalString (owner != null) ''
          chown "${owner}" "${path}"
        ''}
        ${lib.optionalString (group != null) ''
          chgrp "${group}" "${path}"
        ''}
        ${lib.optionalString (mode != null) ''
          chmod "${mode}" "${path}"
        ''}
      fi
    '';
  };
}
