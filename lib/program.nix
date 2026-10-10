{
  pkgs,
  lib,
}: let
  # Recursively collect regular files under `dir`.
  # Returns an attrset of "<path relative to dir>" -> <path>.
  collectFiles = dir: let
    recurse = base: prefix: let
      entries = builtins.readDir base;
    in
      builtins.foldl'
      (
        acc: name: let
          type = entries.${name};
          full = base + "/${name}";
          rel =
            if prefix == ""
            then name
            else "${prefix}/${name}";
        in
          if type == "directory"
          then acc // (recurse full rel)
          else if type == "regular"
          then acc // {"${rel}" = full;}
          else acc
      )
      {}
      (builtins.attrNames entries);
  in
    if builtins.pathExists dir
    then recurse dir ""
    else {};

  # Files under `config/` are copied verbatim into `$XDG_CONFIG_HOME/<target>`.
  staticFiles = {
    dir,
    target,
  }:
    lib.mapAttrs' (rel: path:
      lib.nameValuePair "${target}/${rel}" {source = path;})
    (collectFiles dir);

  # Files under `templates/` are rendered with Jinja2 using `context`.
  render = {
    name,
    dir,
    context,
  }:
    pkgs.runCommand "render-${name}" {
      nativeBuildInputs = [pkgs.jinja2-cli];
    } ''
      mkdir -p "$out"
      printf '%s' ${lib.escapeShellArg (builtins.toJSON context)} > ctx.json

      while IFS= read -r -d "" file; do
        rel="''${file#${dir}/}"
        mkdir -p "$out/$(dirname "$rel")"
        jinja2 --strict "$file" ctx.json > "$out/$rel"
      done < <(find ${dir} -type f -print0)
    '';

  templateFiles = {
    dir,
    target,
    context,
    name,
  }:
    lib.mapAttrs' (
      rel: _path: let
        rendered = render {inherit name dir context;};
      in
        lib.nameValuePair "${target}/${rel}" {source = "${rendered}/${rel}";}
    )
    (collectFiles dir);

  # Files under `nix/` are config fragments merged into the module.
  # A file that is a function is called with `args` (useful to pull in
  # `config`/`lib`/`pkgs`/`myLib`); plain attrsets are merged as-is.
  nixConfig = dir: args:
    lib.mkMerge (
      map (path: let
        m = import path;
      in
        if lib.isFunction m
        then m args
        else m) (
        lib.attrValues (collectFiles dir)
      )
    );

  # Build the home-manager config for a program directory laid out as:
  #
  #   <dir>/
  #     default.nix   calls this function
  #     config/       copied as-is under ~/.config/<target>
  #     templates/    Jinja2 rendered using `context`
  #     nix/          merged into the module config
  mk = {
    dir,
    target,
    context ? {},
    force ? false,
    name ? target,
    args ? {},
  }: let
    entries =
      staticFiles {
        dir = dir + "/config";
        inherit target;
      }
      // templateFiles {
        dir = dir + "/templates";
        inherit target context name;
      };
  in
    lib.mkMerge [
      {
        xdg.configFile =
          if force
          then lib.mapAttrs (_: lib.mkForce) entries
          else entries;
      }
      (nixConfig (dir + "/nix") args)
    ];
in {
  inherit collectFiles staticFiles templateFiles render nixConfig mk;
}
