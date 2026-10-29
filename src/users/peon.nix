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

    users.users.peon = {
      isNormalUser = true;
      description = "peon";
      home = "/home/peon";
      shell = pkgs.fish;
      linger = true;
      extraGroups =
        ["wheel" "networkmanager" "docker" "config-editor"]
        ++ ["video" "input" "render"]; # for sunshine
      # hashedPasswordFile = config.sops.secrets."users/peon/password_hash".path;
    };

    sops.secrets = {
      "host/kkbook/github/key".owner = "peon";
      "ssh/private/kg-continabook/key".owner = "peon";
      "ssh/private/kkbook/key".owner = "peon";
      "ssh/private/kkedge/key".owner = "peon";
      "ssh/private/kknas/key".owner = "peon";
      "ssh/private/kkphone/key".owner = "peon";
      "ssh/private/kkserv/key".owner = "peon";
      "ssh/private/kktab/key".owner = "peon";
      "ssh/private/kkworker/key".owner = "peon";
    };
  };
  home = {
    pkgs,
    myLib,
    # config,
    # homeModules,
    ...
  }: {
    home.username = "peon";
    home.homeDirectory = "/home/peon";
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;

    # systemd.user.services.home-manager-peon.Unit.After = [ "sops-nix.service" ];

    # desktop.niri.enable = true;
    #   desktop.plasma.enable = true;
    #    apps.nvim.enable = true;
    apps.zed = {
      enable = true;
      defaultEditor = true;
    };
    apps.helix = {
      enable = true;
      defaultEditor = false;
    };
    apps.kakoune = {
      enable = true;
      defaultEditor = false;
    };
    apps.lazygit.enable = true;
    apps.opencode.enable = true;
    # apps.tmux = {
    #   enable = true;
    #   leader = "C-a";
    # };
    programs.tmux = {
      enable = true;
      clock24 = true;
      historyLimit = 100000;
      keyMode = "vi";
    };

    apps.fish.enable = true;
    # apps.zsh.enable = true;
    apps.elvish.enable = true;

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
    apps.terminal.kitty = {
      enable = true;
      default = true;
    };
    apps.terminal.wezterm.enable = true;

    apps.ssh = {
      enable = true;
      privateKeys = {
        "kg-continabook" = "ssh/private/kg-continabook/key";
        "kkbook" = "ssh/private/kkbook/key";
        "kkedge" = "ssh/private/kkedge/key";
        "kknas" = "ssh/private/kknas/key";
        "kkphone" = "ssh/private/kkphone/key";
        "kkserv" = "ssh/private/kkserv/key";
        "kktab" = "ssh/private/kktab/key";
        "kkworker" = "ssh/private/kkworker/key";
        "github-priv-key" = "host/kkbook/github/key";
      };
      hosts = myLib.ssh.mkHosts {
        hosts = {
          github = {
            hostname = "github.com";
            user = "git";
            identityFile = "~/.ssh/github-priv-key";
          };
          "kg-continabook" = {
            user = "kg";
            port = 2122;
            identityFile = "~/.ssh/kg-continabook";
          };
          kkbook = {
            ips = ["192.168.3.100"];
            user = "peon";
            port = 2122;
            identityFile = "~/.ssh/kkbook";
          };
          kkedge = {
            user = "wisp";
            port = 2122;
            identityFile = "~/.ssh/kkedge";
          };
          kknas = {
            ips = ["192.168.3.107"];
            user = "wisp";
            port = 2122;
            identityFile = "~/.ssh/kknas";
          };
          kkphone = {
            user = "peon";
            port = 2122;
            identityFile = "~/.ssh/kkphone";
          };
          kkserv = {
            ips = ["192.168.3.5"];
            user = "wisp";
            port = 2122;
            identityFile = "~/.ssh/kkserv";
          };
          kktab = {
            user = "peon";
            port = 2122;
            identityFile = "~/.ssh/kktab";
          };
          kkworker = {
            user = "wisp";
            port = 2122;
            identityFile = "~/.ssh/kkworker";
          };
        };
      };
      sshfs.enable = true;
    };

    # apps.steam.gamescope.enable = true;
    # apps.lutris.gamescope.enable = true;

    apps.niri.enable = true;
    apps.noctalia.enable = true;
    apps.plasma.enable = true;

    apps.blender.enable = true;
    apps.kando.enable = false;

    home.packages = with pkgs; [
      # neovim
      # neovim-remote
      git
      git-lfs
      lazygit
      lazydocker
      brave
      thunderbird
      cloc

      mdv

      spotify
      discord

      keepassxc
      libreoffice
    ];
  };
}
