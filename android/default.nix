{ pkgs }:

let
  python3Packages = pkgs.python3Packages;

  # adbutils — not in nixpkgs; pure-Python ADB client library
  adbutils = python3Packages.buildPythonPackage rec {
    pname = "adbutils";
    version = "2.12.0";
    pyproject = false;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-NlOo+TlzYiDEtfm9lh72YzH5kFpo/ws8lk8c6Z0OaGg=";
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
      hash = "sha256-9vXkAjgsOnN9jtjyhJRs0B1MH0mj4AT4i7v/wIShpfY=";
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

  src = pkgs.fetchPypi {
    inherit pname version;
    hash = "sha256-pMBC+ZFPU0qNqeAAZisyuD2HRFxoFueXHSbx46e4bk4=";
  };

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
  '';

  # Tests require a connected Android device
  doCheck = false;

  pythonImportsCheck = [ "android_mcp" ];

  meta = with pkgs.lib; {
    description = "MCP server for Android debugging via ADB";
    license = licenses.mit;
  };
}
