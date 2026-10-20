{lib, ...}: {
  apps.difftastic.enable = lib.mkDefault true;
  apps.gitDelta.enable = lib.mkDefault true;
}
