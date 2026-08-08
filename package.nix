{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:

let
  version = "0.45.0";

  # Map Nix system -> upstream release asset name + content hash.
  # Regenerate with ./update.sh (see README) when bumping `version`.
  assets = {
    x86_64-linux = {
      name = "rtk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-xMA2+/GB/FXvMpeGyMF+DUJ5crBTuCWUTZaKaq/vG6Q=";
    };
    aarch64-linux = {
      name = "rtk-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-gKdG3TBe+UT/UO8BGuTOOHjdW6iN/jXYWdBUmBkWN8M=";
    };
    x86_64-darwin = {
      name = "rtk-x86_64-apple-darwin.tar.gz";
      hash = "sha256-nqAviJ1aJ3nk+3AN9Fh4JDA8WlfNoi6QPjAFgHn8oO8=";
    };
    aarch64-darwin = {
      name = "rtk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-BkFRz8LVCyTYELBqCvLkG5yUXoNTTkxDjD0+rmB/w/Q=";
    };
  };

  asset =
    assets.${stdenvNoCC.hostPlatform.system}
      or (throw "rtk-nix: no release asset for system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "rtk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };

  # Each asset is a tarball holding a single bare `rtk` binary with no top-level
  # directory, which stdenv's unpackPhase rejects — untar in installPhase instead.
  dontUnpack = true;
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # The aarch64-linux asset is a glibc build needing libc, libm and libgcc_s.
  # autoPatchelfHook resolves libc/libm on its own, but not libgcc_s — without
  # this the aarch64-linux build fails, and CI only *evaluates* that system.
  # (The x86_64-linux asset is static musl, so this is inert there.)
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    tar -xzf "$src"
    install -Dm755 rtk "$out/bin/rtk"
    runHook postInstall
  '';

  meta = {
    description = "CLI proxy that filters and summarizes command output before it reaches an LLM context (unofficial packaging, prebuilt upstream release binary)";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "rtk";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
