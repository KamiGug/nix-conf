{
  path,
  mountPath,
  mode ? "0400",
  owner ? null,
  group ? null,
}:

{
  inherit
    path
    mountPath
    mode
    owner
    group
    ;
}
