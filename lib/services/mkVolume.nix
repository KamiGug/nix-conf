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
# TODO: in let in mkdir -p (builtins.dirOf hostPath)
# TODO: return only a string (docker like volume string definition)
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
