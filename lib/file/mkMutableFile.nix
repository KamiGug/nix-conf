{lib, ...}:
{
  path,
  contents,
  parentService ? null,
  owner ? null,
  group ? null,
  mode ? "0644",
}: let
  serviceName = lib.replaceStrings ["/"] ["@"] path;
in {
  systemd.services."generate-${serviceName}" = {
    description = "Generate ${path}";


    before = if (builtins.isString parentService) then
        [ parentService ]
      else if (builtins.isList parentService) then
        parentService
      else
        [];

    requiredBy = if (builtins.isString parentService) then
        [ parentService ]
      else if (builtins.isList parentService) then
        parentService
      else
        [];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
            mkdir -p "$(dirname ${path})"
            tmp=$(mktemp)
            cat > "$tmp" <<'EOF'
      ${contents}
      EOF
            if ! cmp -s "$tmp" "${path}"; then
              mv "$tmp" "${path}"

              ${lib.optionalString (owner != null) ''
        chown ${owner}${lib.optionalString (group != null) ":${group}"} ${path}
      ''}

              chmod ${mode} ${path}

            else
              rm "$tmp"
            fi

    '';
  };
}
