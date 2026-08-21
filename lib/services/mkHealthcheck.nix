{
  cmd,
  interval ? "30s",
  timeout ? "5s",
  retries ? 3,
  startPeriod ? null,
}:

{
  inherit
    cmd
    interval
    timeout
    retries
    startPeriod
    ;
}
