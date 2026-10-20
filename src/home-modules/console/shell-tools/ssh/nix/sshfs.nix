{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.ssh;
in
  lib.mkIf cfg.sshfs.enable {
    home.packages = [pkgs.sshfs];
  }
