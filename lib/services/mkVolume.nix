{
  hostPath,
  containerPath,

  type ? "bind",

  readOnly ? false,

  create ? true,

  uid ? null,
  gid ? null,

  mode ? null,
}:

{
  inherit
    type
    readOnly
    create
    uid
    gid
    mode
    ;

  hostMount = hostPath;
  containerMount = containerPath;
}
