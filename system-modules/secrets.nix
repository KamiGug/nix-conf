{} :
{
  sops.secrets.peon-password = {
    format = "yaml";
    sopsFile = ../secrets.yml;
    key = "peon-password";
  };
#   assertions = [
#     {
#       assertion = config.sops.secrets.peon-password.path != null;
#       message = "peon-password secret missing; refusing to configure users";
#     }
#   ];

  sops.secrets.peon-password.neededForUsers = true;
}
