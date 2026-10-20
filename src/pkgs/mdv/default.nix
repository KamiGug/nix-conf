{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "mdv";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "posaune0423";
    repo = "mdv";
    rev = "739511ec80d6b2bc552febd47ffce47e1a9d3368";
    hash = "sha256-5pKZ9Y1XKzB4NTqwRZ4WIXJ4sgdzclLFWoCfWZcpDkI=";
  };

  cargoHash = "sha256-BbVOc87Vrth5W9tU1N0/hbefUwM7C4EQyeDqQBEWfsw=";

  meta = {
    description = "Browser-quality Markdown viewer for the terminal";
    homepage = "https://github.com/posaune0423/mdv";
    license = lib.licenses.mit;
    mainProgram = "mdv";
    platforms = lib.platforms.unix;
  };
}
