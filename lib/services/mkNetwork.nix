{
  name,
  driver ? "bridge",
  internal ? false,
  ipv6 ? false,
}:

{
  inherit
    name
    driver
    internal
    ipv6
    ;
}
