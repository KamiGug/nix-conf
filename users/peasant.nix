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

    users.users.peasant = {
      isNormalUser = true;
      description = "Live installer user";
      home = "/home/peasant";
      shell = pkgs.fish;
      initialHashedPassword = "";
      extraGroups = ["wheel" "networkmanager"];
    };
  };
  home = {
    pkgs,
    # config,
    # homeModules,
    ...
  }: {
    home.username = "peasant";
    home.homeDirectory = "/home/peasant";
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;

    apps.zed = {
      enable = true;
      defaultEditor = false;
    };
    apps.helix = {
      enable = true;
      defaultEditor = false;
    };
    apps.kakoune.defaultEditor = false;
    apps.lazygit.enable = true;
    apps.opencode.enable = true;

    apps.fish.enable = true;
    apps.elvish.enable = true;
    apps.terminal.kitty = {
      enable = true;
      default = true;
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
      };
    };

    apps.ssh = {
      enable = true;
      privateKeys = [];
      hosts = {
        github = {
          host = "github.com";
          hostname = "github.com";
          user = "git";
          identityFile = "/home/peasant/.ssh/github-priv-key";
        };
      };
    };

    home.packages = with pkgs; [
      git
      lazygit
    ];
  };
}
