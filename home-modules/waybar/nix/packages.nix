{pkgs, ...}: {
  home.packages = with pkgs; [
    # nerd-fonts.geist-mono
    # font-awesome
    networkmanagerapplet
    blueman
    pavucontrol
  ];
}
