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
        :sh KAKOUNE_SESSION="$kak_session" zellij action new-pane --direction left -- yazi<ret>
      }
    }

    define-user-mode files
    map global files y ':yazi<ret>' -docstring 'yazi'
  '';
}
