{
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatMap
    concatStringsSep
    hasPrefix
    hasSuffix
    isAttrs
    isString
    removeSuffix
    splitString
    ;

  flattenOptions = prefix: set:
    lib.concatLists (
      lib.mapAttrsToList (name: value: let
        path =
          if prefix == ""
          then name
          else "${prefix}/${name}";
      in
        if isAttrs value && value != {}
        then flattenOptions path value
        else [
          {
            name = path;
            inherit value;
          }
        ])
      set
    );
in {
  buildSecrets = {
    root,
    options ? {},
  }: let
    rootPath =
      if builtins.isPath root
      then root
      else /. + root;

    index = file:
      builtins.fromJSON (
        builtins.readFile (
          pkgs.runCommand "sops-index.json"
          {
            nativeBuildInputs = [pkgs.yq-go];
          }
          ''
            yq -o=json 'del(.sops)' ${file} > "$out"
          ''
        )
      );

    # Regular YAML files are secret files.
    # Files beginning with "_" are metadata and are not walked.
    isSecretFile = name: kind:
      kind
      == "regular"
      && (hasSuffix ".yml" name || hasSuffix ".yaml" name)
      && !(hasPrefix "_" name);

    walk = dir: let
      entries = builtins.readDir dir;
    in
      concatMap
      (name: let
        path = dir + "/${name}";
      in
        if entries.${name} == "directory"
        then walk path
        else
          lib.optional
          (isSecretFile name entries.${name})
          path)
      (builtins.attrNames entries);

    # "secrets/user/peon/password.yml"
    # -> ["user" "peon" "password"]
    relSegments = path:
      splitString "/"
      (removeSuffix ".yml"
        (removeSuffix ".yaml"
          (lib.removePrefix
            (toString rootPath + "/")
            (toString path))));

    # Recursively expand YAML mappings into individual string secrets.
    expand = path: let
      doc = index path;
      segments = relSegments path;

      walkValue = keyPath: value:
        if isString value
        then [
          {
            name = concatStringsSep "/" (segments ++ keyPath);
            value = {
              sopsFile = path;
              format = "yaml";
              key = concatStringsSep "/" keyPath;
            };
          }
        ]
        else if isAttrs value
        then
          concatMap
          (key: walkValue (keyPath ++ [key]) value.${key})
          (builtins.attrNames value)
        else
          throw ''
            secrets: ${path}: key '${concatStringsSep "/" keyPath}' \
            must hold a string or mapping, got ${builtins.typeOf value}
          '';
    in
      if doc == null
      then []
      else if isAttrs doc
      then
        concatMap
        (key: walkValue [key] doc.${key})
        (builtins.attrNames doc)
      else throw "secrets: ${path}: expected a YAML mapping at the top level";

    pieces = concatMap expand (walk rootPath);
    names = map (piece: piece.name) pieces;
    dupes =
      lib.subtractLists (lib.unique names) names;

    discovered = lib.listToAttrs pieces;

    flatOptions = lib.listToAttrs (flattenOptions "" options);
    optionNames = builtins.attrNames flatOptions;

    stray =
      lib.subtractLists
      (builtins.attrNames discovered)
      optionNames;
  in
    if dupes != []
    then throw "secrets: name collision: ${concatStringsSep ", " (lib.unique dupes)}"
    else if stray != []
    then throw "secrets: options reference unknown secret(s): ${concatStringsSep ", " stray}"
    else lib.recursiveUpdate discovered flatOptions;
}
