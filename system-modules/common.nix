{ pkgs, config, inputs, ...  }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  sops = {
    defaultSopsFile = ../secrets.yml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };

  # sops.secrets.repo = {
  #   format = "yaml";
  #   sopsFile = ../secrets.yml;
  # };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    tmux
  #   curl
    neovim
  ];

  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    libgcc
    stdenv.cc.cc
    zlib
    openssl
    libxml2
    libclang
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
  services.openssh.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "pl_PL.UTF-8";
  };

  services.xserver.enable = false;


  # Configure keymap in X11
  # services.xserver.xkb = {
  #   layout = "pl";
  #   variant = "";
  # };

  # Configure console keymap
  console.keyMap = "pl";

  # Enable CUPS to print documents.
  services.printing.enable = true;

}
