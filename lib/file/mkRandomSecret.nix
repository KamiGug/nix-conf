{pkgs, ...}:
{
  path,
  command ? "openssl rand -base64 64",
  pkgList ? [ pkgs.openssl ],
  mode ? null,
  user ? null,
  group ? null,
  parentServiceName ? null,
}: let
  inherit (pkgs) lib;
  serviceName = "GenerateRandomSecret-${lib.replaceStrings ["/"] ["@"] path}";
in {
  assertions = [
    {
      assertion = builtins.isString path && path != "";
      message = "mkRandomSecret: `path` must be a non-empty string";
    }
    {
      assertion = builtins.isString command && command != "";
      message = "mkRandomSecret: `command` must be a non-empty string";
    }
    {
      assertion = builtins.isList pkgList;
      message = "mkRandomSecret: `pkgList` must be a list";
    }
    {
      assertion =  mode == null || builtins.isString mode;
      message = "mkRandomSecret: `mode` must be a string";
    }
    {
      assertion = user == null || builtins.isString user;
      message = "mkRandomSecret: `user` must be null or a string";
    }
    {
      assertion = group == null || builtins.isString group;
      message = "mkRandomSecret: `group` must be null or a string";
    }
    {
      assertion = parentServiceName == null
        || builtins.isString parentServiceName
        || builtins.isList parentServiceName;
      message = "mkRandomSecret: parentServiceName must be null, string or list";
    }
  ];

  systemd.services.${serviceName} = {
    description = "Generate random secret ${path}";

    wantedBy = [
      "multi-user.target"
    ];

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

    path = pkgList;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      # if mounting a file that is missing docker creates an empty directory
      rmdir "${path}" > /dev/null 2>&1 || true

      if [ ! -e "${path}" ]; then
        echo "Generating secret ${path}"
        ${command} > "${path}"
      fi


      ${lib.optionalString (mode != null) ''
        echo chmoding ${path} to ${mode}
        chmod "${mode}" "${path}"
      ''}

      ${lib.optionalString (user != null) ''
        echo changing owner of ${path} to ${user}
        chown "${user}" "${path}"
      ''}

      ${lib.optionalString (group != null) ''
        echo changing chgrp of ${path} to ${group}
        chgrp "${group}" "${path}"
      ''}
    '';
  };
}
