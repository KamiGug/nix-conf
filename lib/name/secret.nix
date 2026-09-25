{pkgs}:
let
  inherit (pkgs) lib;
in
{
  pathList,
  name,
}:
assert (lib.isList pathList) || throw "pathList must be a list";
assert (lib.isString name && lib.stringLength name > 0) || throw "name must be a non empty string";
let
  separator = "-";
  prefix = builtins.concatStringsSep separator pathList;
in
  "${prefix}${separator}${name}"
