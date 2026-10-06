{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    apps.zellij.enable = true;
  };

  kakoune = ''
    define-command kakoune-split-right %{
      execute-keys %{
        :sh zellij action new-pane --direction right -- kak -c "$kak_session"<ret>
      }
    }

    define-command kakoune-split-down %{
      execute-keys %{
        :sh zellij action new-pane --direction down -- kak -c "$kak_session"<ret>
      }
    }

    map global normal <a-h> ':kakoune-split-right<ret>' \
      -docstring 'Open Kakoune split to the right'

    map global normal <a-j> ':kakoune-split-down<ret>' \
      -docstring 'Open Kakoune split down'
  '';
}
