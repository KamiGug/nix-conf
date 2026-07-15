{
  # inputs,
  ...
}: {
  system = {
    # config,
    pkgs,
    ...
  }: {

    programs.fish.enable = true;
    users.users.wisp = {
      isNormalUser = true;
      description = "peon";
      home = "/home/peon";
      shell = pkgs.fish;
      extraGroups = ["wheel" "networkmanager" "docker" "config-editor"];
      # hashedPasswordFile = config.sops.secrets.peon-password.path;
    };
  };
  home = {
    pkgs,
    # config,
    # homeModules,
    ...
  }: {
    home.username = "wisp";
    home.homeDirectory = "/home/wisp";
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;

    apps.lazygit.enable = true;
    apps.tmux = {
      enable = true;
      leader = "C-a";
    };
    apps.zsh.enable = true;
    apps.fish.enable = true;
    apps.git = {
      enable = true;
      hosts = {
        "github.com" = {
          name = "Kamil";
          email = "gug.kamil@gmail.com";
        };

        "git.ananas-project.dns-dynamic.net" = {
          name = "Nadir";
          email = "kg@ananas-project.dns-dynamic.net";
        };
      };
    };
    # apps.terminal.enable = true;

    apps.ssh = {
      enable = true;
      privateKeys = [
        # "github-priv-key"
        # "ananas-priv-key"
      ];
      hosts = {
        github = {
          host = "github.com";
          hostname = "github.com";
          user = "git";
          identityFile = "/home/peon/.ssh/github-priv-key";
        };
        # git-ananas = {
        #   host = "git.ananas-project.dns-dynamic.net";
        #   hostname = "git.ananas-project.dns-dynamic.net";
        #   user = "git";
        #   port = 22222;
        #   identityFile = "/home/peon/.ssh/ananas-priv-key";
        # };
      };
      sshfs.enable = true;
    };

    home.packages = with pkgs; [
      git
      git-lfs
      lazygit
    ];
  };
}
