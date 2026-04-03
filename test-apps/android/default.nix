{ pkgs }:

let
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "34" ];
    buildToolsVersions = [ "34.0.0" ];
    includeEmulator = false;
    includeNDK = false;
    includeSources = false;
    includeSystemImages = false;
  };

  inherit (androidComposition) androidsdk;
  sdkHome = "${androidsdk}/libexec/android-sdk";
  buildToolsDir = "${sdkHome}/build-tools/34.0.0";
  platformJar = "${sdkHome}/platforms/android-34/android.jar";

in
pkgs.stdenv.mkDerivation {
  pname = "test-app-android";
  version = "1.0.0";

  src = pkgs.lib.cleanSource ./.;

  nativeBuildInputs = [ pkgs.jdk17_headless pkgs.zip ];

  dontStrip = true;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"

    mkdir -p build/gen build/classes build/apk

    # Compile resources with aapt2
    ${buildToolsDir}/aapt2 compile --dir res -o build/compiled_resources.zip

    # Link resources — generate R.java and base APK with resources
    ${buildToolsDir}/aapt2 link \
      -I "${platformJar}" \
      --manifest AndroidManifest.xml \
      --java build/gen \
      -o build/apk/resources.ap_ \
      build/compiled_resources.zip

    # Compile Java sources (R.java + app code)
    javac \
      -source 11 -target 11 \
      -classpath "${platformJar}" \
      -d build/classes \
      build/gen/com/nixmcpdebugkit/testapp/R.java \
      src/com/nixmcpdebugkit/testapp/MainActivity.java

    # Convert .class files to DEX bytecode
    ${buildToolsDir}/d8 \
      --lib "${platformJar}" \
      --min-api 28 \
      --output build/ \
      $(find build/classes -name '*.class')

    # Assemble APK: start from resource APK, add DEX
    cp build/apk/resources.ap_ build/apk/app-unsigned.apk
    (cd build && zip apk/app-unsigned.apk classes.dex)

    # Zipalign
    ${buildToolsDir}/zipalign -f 4 \
      build/apk/app-unsigned.apk \
      build/apk/app-aligned.apk

    # Create debug keystore and sign the APK
    keytool -genkeypair -v \
      -keystore build/debug.keystore \
      -alias androiddebugkey \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -storepass android -keypass android \
      -dname "CN=Android Debug,O=Android,C=US"

    ${buildToolsDir}/apksigner sign \
      --ks build/debug.keystore \
      --ks-key-alias androiddebugkey \
      --ks-pass pass:android \
      --key-pass pass:android \
      --out build/apk/app.apk \
      build/apk/app-aligned.apk

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp build/apk/app.apk $out/test-app-android.apk
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Minimal Android test app for nix-mcp-debugkit E2E tests";
    platforms = platforms.linux;
  };
}
