{
  lib,
  path,
  parentServiceName ? null,
  owner ? null,
  group ? null,
  mode ? null,
}: let
  serviceName = lib.replaceStrings ["/"] ["@"] path;
in {
  systemd.services."EnsureDir-${serviceName}" = {
    description = "Ensure directory ${path} exists";


    before = lib.mkIf (parentServiceName != null) [
      "${parentServiceName}.service"
    ];

    wantedBy = lib.mkIf (parentServiceName != null) [
      "${parentServiceName}.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      SHOULD_MAKE_DIR=""
      if [ ! -d "${path}" ]; then
          SHOULD_MAKE_DIR="1"
      fi
      mkdir -p "${path}"
      if [ -z "$SHOULD_MAKE_DIR" ]; then
        ${lib.optionalString (owner != null) ''
          chown ${owner}${lib.optionalString (group != null) ":${group}"} ${path}
        ''}
        chmod ${if mode != null then mode else "0770"} ${path}
      else
        echo "Dir ${path} already exists"
        ${lib.optionalString (mode != null) "chmod ${mode} ${path}"}
      fi
    '';
  };
}
