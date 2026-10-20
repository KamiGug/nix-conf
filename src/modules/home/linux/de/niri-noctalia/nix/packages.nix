{pkgs, ...}: {
  home.packages = [
    pkgs.xwayland-satellite #for legacy :D
    # pkgs.noctalia-shell
  ];
}
