{
  config,
  lib,
  programFiles,
  ...
}: {
  programs.lazygit.enable = true;

  # home-manager only writes lazygit/config.yml when `settings != {}`; we render
  # it ourselves via the templates/ dir, so force that file in its place.
  home.file."${config.xdg.configHome}/lazygit/config.yml" = {
    enable = lib.mkForce true;
    source = lib.mkForce programFiles."lazygit/config.yml".source;
  };
}
