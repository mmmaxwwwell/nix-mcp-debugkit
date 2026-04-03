#!/usr/bin/env bash
set -euo pipefail

failed=0

# Check 1: PLAYWRIGHT_BROWSERS_PATH is set and directory exists
if [ -z "${PLAYWRIGHT_BROWSERS_PATH:-}" ]; then
  printf '%s\n' "✗ PLAYWRIGHT_BROWSERS_PATH is not set"
  printf '%s\n' "  → Run mcp-browser via the Nix wrapper to set this automatically"
  failed=1
elif [ ! -d "$PLAYWRIGHT_BROWSERS_PATH" ]; then
  printf '%s\n' "✗ PLAYWRIGHT_BROWSERS_PATH directory does not exist: $PLAYWRIGHT_BROWSERS_PATH"
  printf '%s\n' "  → Ensure playwright-driver.browsers is available in the Nix store"
  failed=1
else
  printf '%s\n' "✓ PLAYWRIGHT_BROWSERS_PATH set: $PLAYWRIGHT_BROWSERS_PATH"
fi

# Check 2: Find Chromium binary and attempt headless launch
if [ "$failed" -eq 0 ]; then
  chromium=""
  for dir in "$PLAYWRIGHT_BROWSERS_PATH"/chromium-*/; do
    candidate="${dir}chrome-linux64/chrome"
    if [ -x "$candidate" ]; then
      chromium="$candidate"
      break
    fi
    # Also check chrome-linux (older layout)
    candidate="${dir}chrome-linux/chrome"
    if [ -x "$candidate" ]; then
      chromium="$candidate"
      break
    fi
  done

  if [ -z "$chromium" ]; then
    printf '%s\n' "✗ Chromium binary not found under $PLAYWRIGHT_BROWSERS_PATH"
    printf '%s\n' "  → Check that playwright-driver.browsers includes chromium"
    failed=1
  else
    version_output=""
    if version_output=$("$chromium" --headless --disable-gpu --dump-dom about:blank 2>&1); then
      chrome_version=$("$chromium" --version 2>&1 || true)
      printf '%s\n' "✓ Chromium launchable: $chrome_version"
    else
      printf '%s\n' "✗ Chromium failed to launch: $chromium"
      printf '%s\n' "  → Error: $version_output"
      failed=1
    fi
  fi
fi

exit "$failed"
