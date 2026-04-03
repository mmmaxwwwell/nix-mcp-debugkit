{ pkgs }:

pkgs.buildNpmPackage rec {
  pname = "mcp-browser";
  version = "0.0.56";

  src = ./.;

  npmDepsHash = "sha256-OFzJcwF4hkwFB9SHw1/me/aY13/uswgtUlk+fbDNiPM=";

  dontNpmBuild = true;

  # Prevent playwright from trying to download browsers during npm install
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postInstall = ''
    # Create the mcp-browser wrapper that invokes the upstream CLI
    mkdir -p $out/bin
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/mcp-browser \
      --add-flags "$out/lib/node_modules/mcp-browser/node_modules/@playwright/mcp/cli.js" \
      --set PLAYWRIGHT_BROWSERS_PATH "${pkgs.playwright-driver.browsers}"

    # Install check script
    install -Dm755 ${./check.sh} $out/libexec/mcp-browser-check.sh

    # Rename the makeWrapper output and create outer wrapper that intercepts --check
    mv $out/bin/mcp-browser $out/bin/.mcp-browser-launch
    cat > $out/bin/mcp-browser <<'WRAPPER'
#!${pkgs.bash}/bin/bash
export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
if [ "''${1:-}" = "--check" ]; then
  exec ${pkgs.bash}/bin/bash "$(dirname "$0")/../libexec/mcp-browser-check.sh"
fi
exec "$(dirname "$0")/.mcp-browser-launch" "$@"
WRAPPER
    chmod +x $out/bin/mcp-browser
  '';

  meta = with pkgs.lib; {
    description = "MCP server for browser debugging via Playwright";
    license = licenses.asl20;
  };
}
