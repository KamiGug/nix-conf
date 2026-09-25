{lib, myLib}@args:
let
  secrets = [
    "kg-continabook"
    "kkbook"
    "kkedge"
    "kknas"
    "kkphone"
    "kkserv"
    "kktab"
    "kktab"
  ];
in
lib.foldl'
  lib.recursiveUpdate
  {}
  [
    (import ./kk-continabook.nix args)
  ]
