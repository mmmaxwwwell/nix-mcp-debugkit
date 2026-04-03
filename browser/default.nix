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
  '';

  meta = with pkgs.lib; {
    description = "MCP server for browser debugging via Playwright";
    license = licenses.asl20;
  };
}
