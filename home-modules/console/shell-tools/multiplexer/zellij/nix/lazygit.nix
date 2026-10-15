{pkgs, ...}: let
  lazygitScript = pkgs.writeShellApplication {
    name = "zellij-lazygit";
    runtimeInputs = [
      pkgs.direnv
      pkgs.git
      pkgs.lazygit
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

      if [ -z "$root" ]; then
        echo "no git repo found for: $PWD"
        echo "press any key to close"
        read -r -n 1 -s
        exit 0
      fi

      cd "$root"

      if [ -f .envrc ]; then
        if ! direnv_env="$(direnv export bash)"; then
          echo "direnv failed for: $PWD"
          echo "press any key to close"
          read -r -n 1 -s
          exit 0
        fi

        eval "$direnv_env"
      fi

      exec lazygit
    '';
  };
in {
  home.packages = [lazygitScript];
}
