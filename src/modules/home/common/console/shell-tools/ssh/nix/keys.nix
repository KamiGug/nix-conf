{
  config,
  osConfig,
  lib,
  ...
}:
with lib; let
  cfg = config.apps.ssh;

  keyPath = name: osConfig.sops.secrets.${name}.path;
in {
  home.activation.installPrivateKeys = lib.hm.dag.entryAfter ["writeBoundary" "sops-nix"] ''
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    ${concatStringsSep "\n" (mapAttrsToList (file: secret: ''
        install -m 600 ${keyPath secret} ~/.ssh/${file}
      '')
      cfg.privateKeys)}
  '';
}
