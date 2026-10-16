{pkgs, ...}: {
  home.packages = with pkgs; [
    elvish
    direnv
    # carapace # make a module
    # atuin # make a module
  ];

  apps.my.scripts.enable = true;
}
