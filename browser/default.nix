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
      --set-default PLAYWRIGHT_BROWSERS_PATH "${pkgs.playwright-driver.browsers}"

    # Install check script
    install -Dm755 ${./check.sh} $out/libexec/mcp-browser-check.sh

    # Rename the makeWrapper output and create outer wrapper that intercepts --check
    mv $out/bin/mcp-browser $out/bin/.mcp-browser-launch
    cat > $out/bin/mcp-browser <<'WRAPPER'
#!${pkgs.bash}/bin/bash
# ─────────────────────────────────────────────────────────────────────
# mcp-browser wrapper
#
# Upstream @playwright/mcp defaults to `--browser chrome`, which refuses
# to accept a Nix-provided Chromium and instead tries to download Google
# Chrome into ~/.cache/ms-playwright at first tool-use. Under an agent's
# sandbox the download silently hangs forever because there's no stdio
# tty for any prompt, and the caller's watchdog eventually kills the
# whole run.
#
# Fix: point the CLI at the chromium binary we *already* have in
# playwright-driver.browsers, and default --browser to chromium so no
# code path requests the `chrome` channel. Callers can still override
# by passing their own --browser / --executable-path / --cdp-endpoint.
# ─────────────────────────────────────────────────────────────────────
export PLAYWRIGHT_BROWSERS_PATH="''${PLAYWRIGHT_BROWSERS_PATH:-${pkgs.playwright-driver.browsers}}"
# Also silence any accidental download attempt from a transitive tool call.
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD="''${PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD:-1}"
export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS="''${PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS:-1}"

if [ "''${1:-}" = "--check" ]; then
  exec ${pkgs.bash}/bin/bash "$(dirname "$0")/../libexec/mcp-browser-check.sh"
fi

# Resolve the chromium binary inside playwright-driver.browsers.
# The directory name is versioned (chromium-<rev>) and changes with
# nixpkgs updates, so we glob rather than hardcode. Preserves user
# override: if PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH is already set
# (e.g. by a test harness or dev override), we honor it.
chromium_bin="''${PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH:-}"
if [ -z "$chromium_bin" ]; then
  for candidate in \
    "$PLAYWRIGHT_BROWSERS_PATH"/chromium-*/chrome-linux*/chrome \
    "$PLAYWRIGHT_BROWSERS_PATH"/chromium-*/chrome-linux/chrome \
    "$PLAYWRIGHT_BROWSERS_PATH"/chromium_headless_shell-*/chrome-headless-shell-linux*/headless_shell \
    ; do
    if [ -x "$candidate" ]; then
      chromium_bin="$candidate"
      break
    fi
  done
fi

# Inject default --browser / --executable-path only when the caller did
# not already specify them.  This preserves override semantics for
# advanced use cases (CDP endpoint, msedge channel, etc.).
args=("$@")
has_browser=0
has_exec_path=0
has_cdp=0
for a in "''${args[@]}"; do
  case "$a" in
    --browser|--browser=*) has_browser=1 ;;
    --executable-path|--executable-path=*) has_exec_path=1 ;;
    --cdp-endpoint|--cdp-endpoint=*) has_cdp=1 ;;
  esac
done
injected=()
if [ "$has_cdp" -eq 0 ]; then
  if [ "$has_browser" -eq 0 ]; then
    injected+=(--browser chromium)
  fi
  if [ "$has_exec_path" -eq 0 ] && [ -n "$chromium_bin" ]; then
    injected+=(--executable-path "$chromium_bin")
  fi
fi

exec "$(dirname "$0")/.mcp-browser-launch" "''${injected[@]}" "''${args[@]}"
WRAPPER
    chmod +x $out/bin/mcp-browser
  '';

  meta = with pkgs.lib; {
    description = "MCP server for browser debugging via Playwright";
    license = licenses.asl20;
  };
}
