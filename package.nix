{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:

let
  version = "1.0.1";

  # Map Nix system -> upstream release asset name + content hash.
  # Regenerate with ./update.sh (see README) when bumping `version`.
  assets = {
    x86_64-linux = {
      name = "rtk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-W5GcO8y3mbZ6YYZtDmF0EKT83xc+JhREDlneL6IANDY=";
    };
    aarch64-linux = {
      name = "rtk-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-zWJ8QJGtkLXlrKg8pa9m7kuKqFN6c2Uz+pBUT0YfHCs=";
    };
    x86_64-darwin = {
      name = "rtk-x86_64-apple-darwin.tar.gz";
      hash = "sha256-S3FrL0XWd95ByZ932acRma0GC5jsL3jvcSiFMSs6ZXg=";
    };
    aarch64-darwin = {
      name = "rtk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-Sq4vYM/EnJ6BuMjFcCCqDLgk2mCMeLTwz1wJiOGegk4=";
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
