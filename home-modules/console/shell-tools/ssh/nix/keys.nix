{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.apps.ssh;

  # Expect sops secrets like:
  # sops.secrets."ssh/id_ed25519".path
  keyPath = name: config.sops.secrets.${name}.path;
in {
  home.activation.installPrivateKeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    ${concatStringsSep "\n" (map (k: ''
        install -m 600 ${keyPath k} ~/.ssh/${baseNameOf k}
      '')
      cfg.privateKeys)}
  '';
}
