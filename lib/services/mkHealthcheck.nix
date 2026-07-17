{
  test,

  interval ? "30s",

  timeout ? "5s",

  retries ? 3,

  startPeriod ? null,
}:

{
  inherit
    test
    interval
    timeout
    retries
    startPeriod
    ;
}
