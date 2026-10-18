{
  config,
  lib,
  pkgs,
  ...
}: let
  # Follow the package option so a future override of it is picked up too.
  zed = config.programs.zed-editor.package;
in {
  # Plain `zeditor <path>` follows whatever open behavior Zed stored (it even
  # prompts for it on first use). Ask for the classic one instead -- new
  # window for directories, reuse for files -- unless the caller picked an
  # open behavior itself: --existing/--new/--add/--reuse, their short flags
  # or short flag clusters like `-we`. --classic has to come first, since Zed
  # treats everything after the first path as a path.
  #
  # hiPrio makes this wrapper win over the `zeditor` shipped by zed-editor
  # in the home-manager profile.
  home.packages = [
    (lib.hiPrio (
      pkgs.writeShellScriptBin "zeditor" ''
        classic=1

        for arg in "$@"; do
          case "$arg" in
            --) break ;;
            --existing|--new|--add|--reuse|--classic)
              classic=0
              break
              ;;
            -?*)
              # Short flags, possibly clustered as in `-we`: only e/n/a/r
              # select an open behavior, `-w` and friends keep the default.
              if [[ "$arg" != --* && "$arg" == *[enar]* ]]; then
                classic=0
                break
              fi
              ;;
          esac
        done

        if [ "$classic" = 1 ]; then
          set -- --classic "$@"
        fi

        exec ${lib.getExe' zed "zeditor"} "$@"
      ''
    ))
  ];
}
