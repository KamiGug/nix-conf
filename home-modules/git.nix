{
  config,
  lib,
  # pkgs,
  ...
}: let
  inherit (lib) mkOption mkEnableOption types concatMapStringsSep;

  cfg = config.apps.git;

  includeIfForHost = host: file: ''
    [includeIf "hasconfig:remote.*.url:git@${host}:*/**"]
      path = ${file}
    [includeIf "hasconfig:remote.*.url:https://${host}/*"]
      path = ${file}
  '';

  gitConfigText = attrs: lib.generators.toINI {} attrs;
in {
  options.apps.git = {
    enable = mkEnableOption "Git configuration with per-host includes";

    user = {
      name = mkOption {
        type = types.str;
        default = "Kamil Gugala";
      };

      email = mkOption {
        type = types.str;
        default = "gug.kamil@gmail.com";
      };
    };
    hosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {type = types.str;};
          email = mkOption {type = types.str;};
        };
      });

      default = {};
      description = "Per-host git identity overrides";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      lfs.enable = true;

      settings = {
        user.name = cfg.user.name;
        user.email = cfg.user.email;
        init.defaultBranch = "master";
        core.autocrlf = "input";
        safe = {
          directory = ["/etc/nixos"];
        };
      };
    };

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
              name = data.name;
              email = data.email;
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
  };
}
