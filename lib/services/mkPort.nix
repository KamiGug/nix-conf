{
  host,
  container,
  protocol ? "tcp",
}:

{
  inherit
    host
    container
    protocol
    ;
}
