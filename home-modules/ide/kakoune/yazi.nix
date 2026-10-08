{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    apps.yazi.enable = true;
  };

  kakoune = ''
    define-command yazi %{
      execute-keys %{
        :sh zellij action new-pane --direction left -n yazi -- env KAKOUNE_SESSION="$kak_session" yazi<ret>
      }
    }

    define-user-mode files
    map global files y ':yazi<ret>' -docstring 'yazi'
  '';
}
