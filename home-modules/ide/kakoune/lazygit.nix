{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    apps.lazygit.enable = true;
    apps.yazi.enable = true;
  };

  kakoune = ''
    define-command lazygit %{
      execute-keys %{
        :sh KAKOUNE_SESSION="$kak_session" zellij action new-pane --floating -- lazygit<ret>
      }
    }

    map global normal <a-g> ':lazygit<ret>' \
      -docstring 'Open Lazygit'
  '';
}
