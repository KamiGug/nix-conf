{
  common = [
    ./zed.nix

    ./terminal/scripts
    ./terminal/shell/fish
    ./terminal/shell/elvish
    ./terminal/shell/zsh

    ./terminal/shell-tools/neovim-fhs.nix
    ./terminal/shell-tools/lazygit.nix
    ./terminal/shell-tools/tmux.nix
    ./terminal/git.nix
    ./terminal/terminal.nix
    ./terminal/shell-tools/ssh.nix
    ./terminal/shell-tools/starship.nix
    ./creative/blender.nix
    ./kando.nix
  ];
  linux = [
    ./de/plasma.nix
    ./de/niri-noctalia.nix
    ./waybar.nix
    ./gaming/steam-alias.nix
    ./gaming/lutris-alias.nix
  ];
  darwin = [
    # ./de/paneru.nix
    ./mac/karabiner-elements.nix
    ./mac/hammerspoon.nix
  ];
}
