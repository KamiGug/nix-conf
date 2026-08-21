{
  pkgs,
  contents,
  path,
  executable ? false,
}: let
  dir = builtins.dirOf path;
  base = builtins.baseNameOf path;
in
  pkgs.runCommand base {} ''
    mkdir -p $out/${dir}

    cat > $out/${path} <<'EOF'
    ${contents}
    EOF

    ${if executable then ''
      chmod +x $out/${path}
    '' else ""}
  ''
