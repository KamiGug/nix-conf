{ config, lib, pkgs, ... }:

let
  cfg = config.apps.nvim;
nvimFhs = pkgs.buildFHSEnv {
  name = "nvim-fhs";

  targetPkgs = pkgs: with pkgs; [
    neovim
    neovim-remote

    git
    lazygit
    fzf
    ripgrep
    ast-grep
    fd
    wget
    unzip
    tree-sitter
    luajit
    lua51Packages.luarocks
    nodejs_20
    python3
    cargo
    rustc
    gcc
    gnumake
    cmake
    pkg-config
    ghostscript
    tectonic
    nodePackages.mermaid-cli

    # c++ stdlib headers for clangd
    clang-tools
    glibc.dev
  ];

  runScript = "nvim";

  profile = ''
  export EDITOR=nvim
    export VISUAL=nvim

    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"

    export npm_config_prefix="$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"

    # --- DYNAMIC HEADER FIX ---
    # Ask the GCC inside the FHS where its C++ headers are located.
    # gcc -E -v outputs the search paths to stderr, so we redirect and grep.
    
    export CPLUS_INCLUDE_PATH=$(gcc -E -Wp,-v -xc++ /dev/null 2>&1 | grep '^ /' | tr '\n' ':' | sed 's/ :/:/g')
    
    # Do the same for C headers just in case
    export C_INCLUDE_PATH=$(gcc -E -Wp,-v -xc /dev/null 2>&1 | grep '^ /' | tr '\n' ':' | sed 's/ :/:/g')
    
    # Combine them for general usage (optional but helpful)
    export CPATH=$CPLUS_INCLUDE_PATH:$C_INCLUDE_PATH
  '';
};

in
{
  options.apps.nvim = {
    enable = lib.mkEnableOption "Neovim setup (FHS sandboxed)";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."nvim".source = pkgs.fetchFromGitHub {
      owner = "KamiGug";
      repo = "nvim-config";
      rev = "HEAD";
      sha256 = "sha256-4yoOqpxYrycyAtQmVfkmaVdPNMba/z9Y5qRisbNs6SY=";
    };

    home.packages = [
      nvimFhs
    ];

    programs.zsh.shellAliases = {
      nvim = "nvim-fhs";
    };

    programs.bash.shellAliases = {
      nvim = "nvim-fhs";
    };
  };
}

