{
  name,
  driver ? "bridge",
  internal ? false,
  ipv6 ? false,
} @ args:
assert builtins.isString name || throw "name must be a string";
assert builtins.isString driver || throw "driver must be a string";
assert builtins.elem driver ["bridge" "macvlan" "ipvlan"] || throw "Invalid network driver for ${name}. Got ${driver}";
assert builtins.isBool internal || throw "internal must be a bool";
assert builtins.isBool ipv6 || throw "ipv6 must be bool"; let
  name = "app-service-" + args.name;
in {
  inherit
    name
    driver
    internal
    ipv6
    ;
}
