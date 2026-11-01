{
  pkgs,
  lib,
}: {
  postgres = import ./postgres.nix {inherit pkgs lib;};
  forgejo = import ./forgejo.nix {inherit pkgs lib;};
  nextcloud = import ./nextcloud.nix {inherit pkgs lib;};
  authentik = import ./authentik.nix {inherit pkgs lib;};
  wiki = import ./wiki.nix {inherit pkgs lib;};
  nginx = import ./nginx.nix {inherit pkgs lib;};
  proxy = import ./proxy {inherit pkgs lib;};
}
