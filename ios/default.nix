{ pkgs }:

pkgs.buildNpmPackage rec {
  pname = "mcp-ios";
  version = "1.5.2";

  src = ./.;

  npmDepsHash = "sha256-G0z0AfsGIoi7AzCbPIfVt9HbB5ZLWKRQx8wMCkUlFRE=";

  dontNpmBuild = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postInstall = ''
    # Create the mcp-ios wrapper that invokes the upstream CLI
    mkdir -p $out/bin
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/mcp-ios \
      --add-flags "$out/lib/node_modules/mcp-ios/node_modules/ios-simulator-mcp/build/index.js"

    # Install check script and create outer wrapper that intercepts --check
    install -Dm755 ${./check.sh} $out/libexec/mcp-ios-check.sh

    mv $out/bin/mcp-ios $out/bin/.mcp-ios-launch
    cat > $out/bin/mcp-ios <<'WRAPPER'
#!${pkgs.bash}/bin/bash
if [ "''${1:-}" = "--check" ]; then
  exec ${pkgs.bash}/bin/bash "$(dirname "$0")/../libexec/mcp-ios-check.sh"
fi
exec "$(dirname "$0")/.mcp-ios-launch" "$@"
WRAPPER
    chmod +x $out/bin/mcp-ios
  '';

  meta = with pkgs.lib; {
    description = "MCP server for iOS simulator debugging";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
