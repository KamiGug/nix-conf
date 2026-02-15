{inputs, ...}: {
  system = {
    config,
    pkgs,
    ...
  }: {
    users.users.root = {
      isNormalUser = false;
      shell = pkgs.zsh;
    };

    programs.zsh.enable = true;
  };

  home = {
    pkgs,
    config,
    homeModules,
    ...
  }: {
    home.username = "root";
    home.homeDirectory = "/root";
    home.stateVersion = "24.05";

    programs.home-manager.enable = true;

    #    apps.nvim.enable = true;
    apps.zsh.enable = true;
    apps.zed.enable = true;
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

    # home.packages = with pkgs; [
    #   git
    #   git-lfs
    #   neovim
    # ];
  };
}
