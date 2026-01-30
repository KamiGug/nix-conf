{ inputs, ... }:
{
system = { config, pkgs, ... }: {
#

  users.users.peon = {
    isNormalUser = true;
    description = "peon";
    home = "/home/peon";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "docker" "config-editor" ];
#     hashedPasswordFile = config.sops.secrets.peon-password.path;
  };
};
home = { pkgs, config, homeModules, ... }:
{
  home.username = "peon";
  home.homeDirectory = "/home/peon";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  apps.nvim.enable = true;
  apps.lazygit.enable = true;
  apps.tmux = {
    enable = true;
    leader = "C-a";
  };
  apps.zsh.enable = true;
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
  apps.terminal.enable = true;

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
  ];
};
}
