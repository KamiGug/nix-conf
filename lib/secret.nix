{ lib }:

let
  mkSecret = { config, name, sopsFile, keyPath }:
    let
      secretName = "${name}";
    in
    {
      # declare the secret
      sops.secrets.${secretName} = {
        inherit sopsFile keyPath;
      };

      # return an accessor
      value = config.sops.secrets.${secretName}.path;
    };
in
{
  inherit mkSecret;
}
