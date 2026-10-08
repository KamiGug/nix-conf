{
  common = [
    ./zed.nix

    ./console/scripts
    ./console/shell/fish
    ./console/shell/elvish
    ./console/shell/zsh

    ./console/shell-tools/neovim-fhs.nix
    ./console/shell-tools/lazygit
    ./console/shell-tools/difftastic.nix
    ./console/shell-tools/git-delta.nix
    ./console/shell-tools/multiplexer/tmux
    ./console/git.nix
    ./console/terminal
    ./console/terminal/kitty
    ./console/terminal/wezterm
    ./console/shell-tools/ssh.nix
    ./console/shell-tools/starship.nix
    ./creative/blender.nix
    ./kando.nix
    ./ide/kakoune
    ./ide/helix
    ./ide/nvim
    ./console/shell-tools/yazi
    ./console/shell-tools/multiplexer/zellij
    ./console/opencode
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
