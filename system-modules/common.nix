{
  pkgs,
  # config,
  # inputs,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nixpkgs.config.allowUnfree = true;

  home-manager.backupFileExtension = "bak";
  # sops.secrets.repo = {
  #   format = "yaml";
  #   sopsFile = ../secrets.yml;
  # };

  services.openssh.enable = true;
  environment.systemPackages = with pkgs; [
    git
    tmux
    curl
    wget
    # zed-editor
    neovim
    ripgrep
    tree
    sl
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.


  users.groups.config-editor = {};
}
