{
  writeShellApplication,
  git,
}:
writeShellApplication {
  name = "nix-conf-clone";

  runtimeInputs = [git];

  text = ''
    REPO_HTTPS="''${NIX_CONF_REPO_HTTPS:-https://github.com/KamiGug/nix-conf.git}"
    REPO_SSH="''${NIX_CONF_REPO_SSH:-git@github.com:KamiGug/nix-conf.git}"
    BRANCH="''${NIX_CONF_BRANCH:-master}"
    DEST="''${1:-/etc/nixos}"

    if [ -e "$DEST/.git" ]; then
      echo "nix-conf-clone: $DEST is already a git repository" >&2
      exit 1
    fi

    git clone --branch "$BRANCH" "$REPO_HTTPS" "$DEST"
    git -C "$DEST" remote set-url origin "$REPO_SSH"

    echo "nix-conf-clone: cloned $REPO_HTTPS ($BRANCH) into $DEST"
    echo "nix-conf-clone: origin -> $REPO_SSH"
  '';
}
