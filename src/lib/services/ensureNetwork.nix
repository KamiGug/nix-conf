{pkgs, ...}: {
  name,
  postfix ? "",
  backend ? "podman",
}: let
  fullName = "app-service-${name}${postfix}";
  unitName = "ensure-${name}${postfix}-${backend}-network-exists";
  bin = pkgs.lib.getExe pkgs.${backend};
in
  assert builtins.isString name || throw "network name must be a string";
  assert builtins.isString postfix || throw "postfix must be a string";
  assert builtins.elem backend ["docker" "podman"] || throw "backend must be either 'docker' or 'podman'"; {
    systemd.services.${unitName} = {
      description = "Ensure that ${fullName} network exists for ${backend}";
      wantedBy = ["multi-user.target"];
      after = ["${backend}.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = "${bin} network exists ${fullName} || ${bin} network create ${fullName}";
    };
  }
