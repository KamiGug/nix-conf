{
  pkgs,
  lib,
  ...
}: {
  src,
  dockerfile ? "Dockerfile",
  secretEnvs ? [],
  extraFiles ? {},
}: let
  entrypoint = ./secret-entrypoint.sh;

  # The build context must never contain a secret file. Services keep their
  # secrets in /run/secrets via sops-nix, but filter obvious accidental
  # additions out of the copied tree as a second line of defence.
  filteredSrc = builtins.path {
    path = src;
    name = "service-src";
    filter = path: _type: let
      base = baseNameOf (toString path);
    in
      !(lib.hasPrefix ".env" base)
      && !(lib.hasSuffix ".key" base)
      && !(lib.hasSuffix ".pem" base)
      && !(lib.hasSuffix ".p12" base)
      && !(lib.hasSuffix ".pfx" base)
      && !(lib.hasInfix "secret" base && base != "secret-entrypoint.sh");
  };

  strippedDockerfile =
    lib.concatStringsSep "\n" (
      map
      (line:
        if lib.any (name: lib.hasInfix "ENV ${name}" line) secretEnvs
        then "# stripped secret env"
        else line)
      (lib.splitString "\n" (builtins.readFile (filteredSrc + "/${dockerfile}")))
    )
    + "\n";

  extraFileLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (dest: source: ''
      install -D -m 0755 ${source} "$out"/${dest}
    '')
    extraFiles);

  context = pkgs.runCommand "service-context" {} ''
        mkdir -p "$out"
        cp -R ${filteredSrc}/. "$out"/
        chmod -R u+w "$out"
        install -m 0755 ${entrypoint} "$out"/secret-entrypoint.sh
        ${extraFileLines}
        cat >"$out"/${dockerfile} <<'DOCKERFILE'
    ${strippedDockerfile}
    DOCKERFILE
  '';
in {
  inherit context;
  dockerfile = context + "/${dockerfile}";
}
