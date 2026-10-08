{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}: let
  version = "2.0.24";
  sources = {
    x86_64-linux = {
      url = "https://opencode.ai/files/bin/${version}/opencode-linux-x64.tar.gz";
      hash = "sha256-jyZrMEP5bWB3/ARZvd5y5Bmb+Iwn5q9XMEffiuOFM0U=";
    };
    aarch64-linux = {
      url = "https://opencode.ai/files/bin/${version}/opencode-linux-arm64.tar.gz";
      hash = "sha256-I1ZVx69pZKz8xO9X9BZSExBHcNDK0mNJXUJqcmGXg3A=";
    };
    aarch64-darwin = {
      url = "https://opencode.ai/files/bin/${version}/opencode-darwin-arm64.zip";
      hash = "sha256-ZANqCNNJWWOKZ+CRN63RASWau0yPUNK/dbxxEv+MgEI=";
    };
    x86_64-darwin = {
      url = "https://opencode.ai/files/bin/${version}/opencode-darwin-x64.zip";
      hash = "sha256-uewTuDxB/m5vijx2dyfbHDXW/dT5SFoNZKthZtsFb9Y=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
    or (throw "opencode-v2: unsupported system `${stdenv.hostPlatform.system}`");
in
  stdenv.mkDerivation {
    pname = "opencode";
    inherit version;

    src = fetchurl {inherit (source) url hash;};

    sourceRoot = ".";

    nativeBuildInputs =
      lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook
      ++ lib.optional stdenv.hostPlatform.isDarwin unzip;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 opencode $out/bin/opencode
      runHook postInstall
    '';

    meta = {
      description = "OpenCode V2 AI coding agent for the terminal";
      homepage = "https://opencode.ai";
      license = lib.licenses.mit;
      mainProgram = "opencode";
      platforms = builtins.attrNames sources;
    };
  }
