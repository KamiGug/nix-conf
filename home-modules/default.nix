{
  common = [
    ./zed.nix

    ./terminal/scripts
    ./terminal/shell/fish
    ./terminal/shell/elvish
    ./terminal/shell/zsh

    ./terminal/shell-tools/neovim-fhs.nix
    ./terminal/shell-tools/lazygit
    ./terminal/shell-tools/multiplexer/tmux
    ./terminal/git.nix
    ./terminal/terminal.nix
    ./terminal/shell-tools/ssh.nix
    ./terminal/shell-tools/starship.nix
    ./creative/blender.nix
    ./kando.nix
    ./ide/kakoune
    ./terminal/shell-tools/yazi
    ./terminal/shell-tools/multiplexer/zellij
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
