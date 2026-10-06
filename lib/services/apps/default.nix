{pkgs, ...}: {
  authentik = import ./authentik {inherit pkgs;};
  nextcloud = import ./nextcloud {inherit pkgs;};
  dbs = {
    postgres = import ./dbs/postgres {inherit pkgs;};
  };
}
