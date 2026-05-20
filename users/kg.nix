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

    environment.shells = with pkgs; [
      fish
    ];

    users.users.kg = {
      # isNormalUser = true;
      description = "kg";
      home = "/Users/kg";
      shell = pkgs.fish;
      # extraGroups = ["wheel" "networkmanager" "docker" "config-editor"];
      # hashedPasswordFile = config.sops.secrets.kg-password.path;
    };

    system.defaults.dock = {
      autohide = true;

      persistent-apps = [
        "/Users/kg/Applications/Home Manager Apps/Brave Browser.app"
        "/Users/kg/Applications/Home Manager Apps/Thunderbird.app"
        "/Users/kg/Applications/Home Manager Apps/kitty.app"
        "/System/Applications/App Store.app"
        "/Users/kg/Applications/Home Manager Apps/Discord.app"
        "/Users/kg/Applications/Home Manager Apps/Spotify.app"
        "/Users/kg/Applications/Home Manager Apps/KeePassXC.app"
        "/Users/kg/Applications/Home Manager Apps/Zed.app"
        "/Users/kg/Applications/Home Manager Apps/PhpStorm.app"
      ];
    };
    # homebrew.brews = [ "docker" ];
    homebrew.casks = ["tunnelblick"];
  };
  home = {
    pkgs,
    # config,
    # homeModules,
    ...
  }: {
    home.username = "kg";
    home.homeDirectory = "/Users/kg";
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;

    apps.zed.enable = true;
    apps.lazygit.enable = true;
    programs.tmux = {
      enable = true;
      clock24 = true;
      historyLimit = 100000;
      keyMode = "vi";
    };
    apps.fish = {
      enable = true;
    };

    apps.zsh = {
      enable = true;
    };

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
        "gitlab-p2.autobid.de" = {
          name = "Kamil Gugała";
          email = "k.gugala@contina.pl";
        };
      };
    };
    apps.terminal.enable = true;

    apps.karabiner.enable = true;

    apps.hammerspoon = {enable = true;};
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
          identityFile = "/Users/kg/.ssh/github-priv-key";
        };
        "gitlab-p2.autobid.de" = {
          host = "gitlab-p2.autobid.de";
          hostname = "gitlab-p2.autobid.de";
          user = "git";
          port = 10022;
          identityFile = "/Users/kg/.ssh/gitlab-contina";
        };
        # git-ananas = {
        #   host = "git.ananas-project.dns-dynamic.net";
        #   hostname = "git.ananas-project.dns-dynamic.net";
        #   user = "git";
        #   port = 22222;
        #   identityFile = "/Users/kg/.ssh/ananas-priv-key";
        # };
      };
      sshfs.enable = true;
    };
    home.packages = with pkgs; [
      # neovim
      # neovim-remote
      git
      git-lfs
      lazygit
      lazydocker
      brave
      thunderbird

      spotify
      discord
      openvpn

      keepassxc
      jetbrains.phpstorm

      docker
      colima

      bruno
      bruno-cli
    ];
    targets.darwin.copyApps.enable = true;
    targets.darwin.linkApps.enable = false;
  };
}
