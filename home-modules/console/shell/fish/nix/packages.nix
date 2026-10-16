{pkgs, ...}: {
  home.packages = with pkgs; [
    direnv
  ];

  apps.my.scripts.enable = true;
}
