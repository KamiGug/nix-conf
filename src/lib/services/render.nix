{
  pkgs,
  lib,
  ...
}: {
  template,
  vars,
  name ? null,
}: let
  base =
    if name != null
    then name
    else baseNameOf (toString template);
  safeName = lib.replaceStrings ["/" "." " "] ["-" "-" "-"] base;
  templateFile = builtins.path {
    path = template;
    name = baseNameOf (toString template);
  };
  varsFile = pkgs.writeText "${safeName}.vars.json" (builtins.toJSON vars);
in
  pkgs.runCommand "render-${safeName}" {
    nativeBuildInputs = [pkgs.jinja2-cli];
    passthru = {inherit varsFile;};
  } ''
    mkdir -p "$out"
    jinja2 --strict --format=json ${lib.escapeShellArg (toString templateFile)} ${lib.escapeShellArg (toString varsFile)} > "$out"/${lib.escapeShellArg base}
  ''
