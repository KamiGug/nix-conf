{...}: {
  system = {pkgs, ...}: {
    users.users.root = {
      isNormalUser = false;
      shell = pkgs.zsh;
    };

    programs.zsh.enable = true;
  };

  home = {...}: {
    home = {
      username = "root";
      homeDirectory = "/root";
      stateVersion = "24.05";
    };

    programs.home-manager.enable = true;

    apps = {
      zsh.enable = true;
      zed.enable = true;
      git = {
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
    };

    # home.packages = with pkgs; [
    #   git
    #   git-lfs
    #   neovim
    # ];
  };
}
