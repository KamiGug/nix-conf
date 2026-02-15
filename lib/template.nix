{ file, replacements }:

let
  # Build lists of placeholders and values
  keys = builtins.attrNames replacements;
  vals = builtins.attrValues replacements;

  placeholders = map (k: "<<" + k + ">>") keys;
in
  builtins.replaceStrings placeholders vals (builtins.readFile file)
