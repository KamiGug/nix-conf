{ targetPrefix, templateDir, replacements ? {} }:

let
  keys = builtins.attrNames replacements;
  vals = builtins.attrValues replacements;

  placeholders = map (k: "\${" + k + "}") keys;

  replaceInFile = path:
    builtins.replaceStrings placeholders vals (builtins.readFile path);

  collect = dir: prefix:
    let
      entries = builtins.readDir dir;
      names = builtins.attrNames entries;
    in
      builtins.foldl'
        (acc: name:
          let
            type = entries.${name};
            fullPath = dir + "/${name}";
            relPath =
              if prefix == "" then name
              else prefix + "/${name}";
          in
            if type == "directory" then
              acc // (collect fullPath relPath)
            else if type == "regular" then
              acc // {
                "${targetPrefix}/${relPath}" = {
                  text = replaceInFile fullPath;
                };
              }
            else
              acc
        )
        {}
        names;

in
collect templateDir ""
