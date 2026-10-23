{
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrValues
    concatMap
    concatStringsSep
    hasPrefix
    hasSuffix
    isAttrs
    isString
    mapAttrs'
    nameValuePair
    removeSuffix
    splitString
    ;
in {
  buildSecrets = {
    root,
    options ? {},
  }: let
    rootPath =
      if builtins.isPath root
      then root
      else builtins.toPath root;

    index = file:
      builtins.fromJSON (builtins.readFile (pkgs.runCommand "sops-index.json"
        {nativeBuildInputs = [pkgs.yq-go];}
        ''
          yq -o=json 'del(.sops)' ${file} > $out
        ''));

    # Files are secrets when they are regular YAML files. A leading "_"
    # marks public metadata that must not be walked.
    isSecretFile = name: kind:
      kind
      == "regular"
      && (hasSuffix ".yml" name || hasSuffix ".yaml" name)
      && !(hasPrefix "_" name);

    # Unconditional recursion to the leaves (no default.nix stop-rule).
    walk = dir: let
      entries = builtins.readDir dir;
    in
      concatMap (name: let
        p = dir + "/${name}";
      in
        if entries.${name} == "directory"
        then walk p
        else lib.optional (isSecretFile name entries.${name}) p)
      (builtins.attrNames entries);

    # "…/secrets/users/darwin/post2016/dude.yml" -> ["users" "darwin" "post2016" "dude"]
    relSegments = p:
      splitString "/" (removeSuffix ".yml" (removeSuffix ".yaml"
          (lib.removePrefix (toString rootPath + "/") (toString p))));

    # One entry per top-level YAML key of the file.
    expand = p: let
      doc = index p;
      segs = relSegments p;
    in
      if doc == null || !isAttrs doc
      then []
      else
        lib.mapAttrsToList (key: value:
          if !isString value
          then throw "secrets: ${p}: key '${key}' must hold a string, got ${builtins.typeOf value}"
          else {
            name = concatStringsSep "/" (segs ++ [key]);
            value = {
              sopsFile = p;
              format = "yaml";
              key = key;
            };
          })
        doc;

    flattenOptions = set:
      lib.concatLists (lib.mapAttrsToList (name: value: let
        isLeaf =
          !isAttrs value
          || value == {}
          || !(lib.all isAttrs (attrValues value));
      in
        if isLeaf
        then [
          {
            name = name;
            value = value;
          }
        ]
        else
          lib.map (
            pair: {
              name = "${name}/${pair.name}";
              value = pair.value;
            }
          ) (flattenOptions value))
      set);

    pieces = concatMap expand (walk rootPath);
    names = map (piece: piece.name) pieces;
    dupes = lib.subtractLists (lib.unique names) names;

    discovered = lib.listToAttrs pieces;
    flatOptions = lib.listToAttrs (flattenOptions options);
    optionNames = builtins.attrNames flatOptions;
    stray = lib.subtractLists (builtins.attrNames discovered) optionNames;
  in
    if stray != []
    then throw "secrets: options reference unknown secret(s): ${concatStringsSep ", " stray}"
    else if dupes != []
    then throw "secrets: name collision: ${concatStringsSep ", " dupes}"
    else lib.recursiveUpdate discovered flatOptions;
}
