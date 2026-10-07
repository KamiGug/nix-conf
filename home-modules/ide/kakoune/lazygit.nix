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

    define-user-mode tools
    map global user c ':enter-user-mode code<ret>' -docstring 'code/tools'
    map global user f ':enter-user-mode files<ret>' -docstring 'files'

    define-user-mode code
    map global code g ':lazygit<ret>' -docstring 'lazygit'
  '';
}
