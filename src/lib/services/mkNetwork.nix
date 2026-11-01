{
  name,
  postfix ? "",
  driver ? "bridge",
  internal ? false,
  ipv6 ? false,
}: let
  fullName = "app-service-${name}${postfix}";
in
  assert builtins.isString name || throw "name must be a string";
  assert builtins.isString postfix || throw "postfix must be a string";
  assert builtins.isString driver || throw "driver must be a string";
  assert builtins.elem driver ["bridge" "macvlan" "ipvlan"] || throw "Invalid network driver for ${name}. Got ${driver}";
  assert builtins.isBool internal || throw "internal must be a bool";
  assert builtins.isBool ipv6 || throw "ipv6 must be bool"; {
    inherit
      fullName
      driver
      internal
      ipv6
      ;
    name = fullName;
  }
