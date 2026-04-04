#!/usr/bin/env bash
# tests/browser-e2e-all.sh — Run browser E2E tests for Firefox and WebKit
# CI-only: installs browser engines via npx playwright install (non-Nix).
# Delegates actual test logic to browser-e2e.sh with BROWSER_TYPE set.
#
# Environment variables:
#   TEST_WEB_DIR       — path to the test-app-web output directory (required)
#   BROWSER_E2E_PORT   — base HTTP port (default: 8787; incremented per browser)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Step 1: Install Firefox and WebKit via Playwright ---
echo "=== Installing Firefox and WebKit via Playwright ==="
npx playwright install firefox webkit

# --- Step 2: Run tests for each browser ---
BROWSERS=("firefox" "webkit")
BASE_PORT="${BROWSER_E2E_PORT:-8787}"
OVERALL_EXIT=0
port_offset=1

for browser in "${BROWSERS[@]}"; do
  # Use a unique port per browser to avoid conflicts
  browser_port=$(( BASE_PORT + port_offset ))
  (( port_offset++ )) || true

  echo ""
  echo "=========================================="
  echo "=== Running E2E tests: $browser (port $browser_port) ==="
  echo "=========================================="

  if BROWSER_TYPE="$browser" BROWSER_E2E_PORT="$browser_port" \
      bash "$SCRIPT_DIR/browser-e2e.sh"; then
    echo "=== $browser: PASSED ==="
  else
    echo "=== $browser: FAILED ==="
    OVERALL_EXIT=1
  fi
done

# --- Step 3: Summary ---
echo ""
echo "=========================================="
echo "=== Browser E2E All — Summary ==="
echo "=========================================="
for browser in "${BROWSERS[@]}"; do
  result_file="test-logs/browser-${browser}/summary.json"
  if [[ -f "$result_file" ]]; then
    pass=$(jq -r '.pass' "$result_file")
    fail=$(jq -r '.fail' "$result_file")
    echo "  $browser: pass=$pass fail=$fail"
  else
    echo "  $browser: no results (test may not have run)"
  fi
done

exit "$OVERALL_EXIT"
