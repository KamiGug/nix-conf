{
  common = [
    ./zed.nix

  ./terminal/fish.nix
  ./terminal/zsh.nix
  ./terminal/neovim-fhs.nix
  ./terminal/lazygit.nix
  ./terminal/tmux.nix
  ./terminal/git.nix
  ./terminal/terminal.nix
  ./terminal/ssh.nix
  ./terminal/starship.nix
  ./creative/blender.nix
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
