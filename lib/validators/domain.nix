domain:
builtins.isString domain
&&
builtins.match
  "^https?://([a-zA-Z0-9-]+\\.)+[a-zA-Z0-9-]+(:[0-9]+)?(/.*)?$"
  domain
  != null
