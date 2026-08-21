{pkgs, ...} :
{
  name,
  # TODO: make this rootless
  # user ? null,
  backend ? "podman"
}:
assert builtins.isString name || throw "network name must be a string";
assert builtins.elem backend ["docker" "podman"] || throw "backend must be either 'docker' or 'podman'";
let
  bin = pkgs.lib.getBin pkgs.${backend};
in
{
  systemd.services."ensure-${name}-${backend}-network-exists" = {
    Description = "Ensure that ${name} network exists for ${backend}";
    wantedBy = [ "multi-user.target" ];
    after = [ "${backend}.service" ];

    serviceConfig = {
      Type = "oneshot";
      # RemainAfterExit = "true";
    };

    script =
      "${bin} network exists ${name} || ${bin} network create ${name}";
  };
}
