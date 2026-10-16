{
  config,
  lib,
  ...
}: let
  inherit (lib) concatMapStringsSep;

  cfg = config.apps.git;

  includeIfForHost = host: file: ''
    [includeIf "hasconfig:remote.*.url:git@${host}:*/**"]
      path = ${file}
    [includeIf "hasconfig:remote.*.url:https://${host}/*"]
      path = ${file}
  '';

  gitConfigText = attrs: lib.generators.toINI {} attrs;
in {
  home.file = let
    includes =
      concatMapStringsSep "\n"
      (
        host:
          includeIfForHost
          host
          "~/.config/git/gitconfig-${host}"
      )
      (lib.attrNames cfg.hosts);

    perHostFiles =
      lib.mapAttrs'
      (host: data: {
        name = ".config/git/gitconfig-${host}";
        value.text = gitConfigText {
          user = {
            inherit (data) name email;
          };
        };
      })
      cfg.hosts;
  in
    perHostFiles
    // {
      ".gitconfig".text = ''
        ${includes}
      '';
    };
}
