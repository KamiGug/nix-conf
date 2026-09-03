{
  hostPath,
  containerPath,

  type ? "bind",

  readOnly ? false,

  create ? true,

  owner ? null,
  group ? null,

  mode ? null,
}: {
  inherit
    type
    readOnly
    create
    owner
    group
    mode
    ;

  hostMount = hostPath;
  containerMount = containerPath;
}
