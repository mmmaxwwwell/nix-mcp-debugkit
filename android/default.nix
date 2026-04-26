{ pkgs }:

let
  inherit (pkgs) python3Packages;

  # adbutils — not in nixpkgs; pure-Python ADB client library
  adbutils = python3Packages.buildPythonPackage rec {
    pname = "adbutils";
    version = "2.12.0";
    format = "setuptools";

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-NlOo85c1YgvEWxXuLnoA5QLJ8aJZRS4fsru6PqWdDmg=";
    };

    # Ensure pbr uses the correct version without git
    PBR_VERSION = version;

    nativeBuildInputs = with python3Packages; [
      pbr
      setuptools
    ];

    propagatedBuildInputs = with python3Packages; [
      requests
      deprecation
      retry2
      pillow
    ];

    # Tests require a connected Android device
    doCheck = false;

    pythonImportsCheck = [ "adbutils" ];
  };

  # uiautomator2 — not in nixpkgs; Android UI automation library
  uiautomator2 = python3Packages.buildPythonPackage rec {
    pname = "uiautomator2";
    version = "3.5.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-9vXkAjgsOmYtvaCs6JxpHI0/mqNAQS+Lv89fCCSaIaY=";
    };

    # Upstream uses poetry-dynamic-versioning, but version is already set in
    # the sdist; swap to plain poetry-core to avoid the extra build dep.
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'requires = ["poetry-core>=1.0.0", "poetry-dynamic-versioning>=1.0.0,<2.0.0"]' \
                        'requires = ["poetry-core>=1.0.0"]' \
        --replace-fail 'build-backend = "poetry_dynamic_versioning.backend"' \
                        'build-backend = "poetry.core.masonry.api"'
    '';

    nativeBuildInputs = with python3Packages; [
      poetry-core
    ];

    propagatedBuildInputs = with python3Packages; [
      requests
      lxml
      adbutils
      pillow
      retry2
    ];

    # Tests require a connected Android device
    doCheck = false;

    pythonImportsCheck = [ "uiautomator2" ];
  };

in
python3Packages.buildPythonApplication rec {
  pname = "android-mcp";
  version = "0.1.0";
  pyproject = true;

  src = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/00/7c/b4b26166bccc0e57712cdd02988431054a3cd7f1464a7562935c54022b74/android_mcp-0.1.0.tar.gz";
    hash = "sha256-pMBC+VH62smwmmjYdSROL0wayZ0uT8JND5jKkdXADfg=";
  };

  # Defer device connection until first tool call so the MCP `initialize`
  # handshake completes even when the device's atx-agent isn't ready. See
  # the patch header for the full rationale.
  patches = [ ./defer-device-init.patch ];

  nativeBuildInputs = with python3Packages; [
    hatchling
    pkgs.makeWrapper
  ];

  propagatedBuildInputs = with python3Packages; [
    fastmcp
    ipykernel
    pillow
    tabulate
    uiautomator2
  ];

  postFixup = ''
    wrapProgram $out/bin/android-mcp \
      --prefix PATH : ${pkgs.android-tools}/bin

    # Install check script and create outer wrapper that intercepts --check
    install -Dm755 ${./check.sh} $out/libexec/android-mcp-check.sh

    # wrapProgram already created .android-mcp-wrapped (original) and
    # android-mcp (env wrapper). Rename the env wrapper and add our shim.
    mv $out/bin/android-mcp $out/bin/.android-mcp-launch
    cat > $out/bin/android-mcp <<'WRAPPER'
#!${pkgs.bash}/bin/bash
export PATH="${pkgs.android-tools}/bin:''${PATH:-}"
if [ "''${1:-}" = "--check" ]; then
  exec ${pkgs.bash}/bin/bash "$(dirname "$0")/../libexec/android-mcp-check.sh"
fi
exec "$(dirname "$0")/.android-mcp-launch" "$@"
WRAPPER
    chmod +x $out/bin/android-mcp

    # Expose as mcp-android (expected by smoke tests and users)
    ln -s android-mcp $out/bin/mcp-android
  '';

  # Tests require a connected Android device
  doCheck = false;

  pythonImportsCheck = [ "android_mcp" ];

  meta = with pkgs.lib; {
    description = "MCP server for Android debugging via ADB";
    license = licenses.mit;
  };
}
