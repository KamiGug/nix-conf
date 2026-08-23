{pkgs, ...}@args:
{
  # authentik = import ./authentik;
  nextcloud = import ./nextcloud { inherit pkgs; };
  dbs = {
    postgres = import ./postgres { inherit pkgs; };
  };
}
