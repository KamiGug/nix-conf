{
  lib,
  rustPlatform,
  fetchCrate,
}: let
  pname = "hx-remote";
  version = "0.1.4";
in
  rustPlatform.buildRustPackage {
    inherit pname version;

    src = fetchCrate {
      inherit pname version;
      hash = "sha256-tr11g26rzHJzT/3EwLtCs9hy8rSSzCiP9M2k7HwHnKA=";
    };

    cargoHash = "sha256-QdEWfCvURXShNm5SYH5nzVfwftbooNIq1aM8mQoIHMM=";

    preCheck = ''
      export HOME=$(mktemp -d)
      export XDG_RUNTIME_DIR=$(mktemp -d)
    '';

    meta = {
      description = "Open files in new or existing Helix sessions through a tiny LSP bridge";
      homepage = "https://github.com/FluxKraken/hxr";
      license = lib.licenses.mit;
      mainProgram = "hxr";
      platforms = lib.platforms.unix;
    };
  }
