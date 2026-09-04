{
  cmd,
  interval ? "30s",
  timeout ? "5s",
  retries ? 3,
  startPeriod ? "5s",
}:
assert (builtins.isString cmd) || throw "cmd must be a string";
assert (builtins.isString interval) || throw "interval must be a string";
assert (builtins.isString timeout) || throw "timeout must be a string";
assert (builtins.isInt retries) || throw "retries must be an int";
assert (builtins.isString startPeriod) || throw "startPeriod must be a string"; {
  inherit
    cmd
    interval
    timeout
    retries
    startPeriod
    ;
}
