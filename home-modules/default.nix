{
  common = [
    ./zed.nix

    ./terminal/scripts
    ./terminal/shell/fish
    ./terminal/shell/elvish
    ./terminal/shell/zsh

    ./terminal/neovim-fhs.nix
    ./terminal/lazygit.nix
    ./terminal/tmux.nix
    ./terminal/git.nix
    ./terminal/terminal.nix
    ./terminal/ssh.nix
    ./terminal/starship.nix
    ./creative/blender.nix
    ./gaming/steam-alias.nix
    ./gaming/lutris-alias.nix
    ./terminal/ssh.nix
  ];
  linux = [
    ./de/plasma.nix
    ./de/niri-noctalia.nix
    ./waybar.nix
  ];
  darwin = [
    # ./de/paneru.nix
    ./mac/karabiner-elements.nix
    ./mac/hammerspoon.nix
  ];
}
