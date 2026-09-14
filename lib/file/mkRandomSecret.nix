{
  lib,
  path,
  command ? "openssl rand -base64 64",
  mode ? null,
  user ? null,
  group ? null,

}: let
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
  ];

  systemd.services.${serviceName} = {
    description = "Generate random secret ${path}";

    wantedBy = [
      "multi-user.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

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
