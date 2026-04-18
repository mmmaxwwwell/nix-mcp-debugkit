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

# Check 1b: user-data-dir base is writable. @playwright/mcp needs to
# mkdir a profile directory on startup; by default it derives the path
# from PLAYWRIGHT_BROWSERS_PATH (the Nix store, read-only), which fails
# with ENOENT. The wrapper injects --user-data-dir to a writable path
# unless the caller opted into --isolated or their own --user-data-dir.
udd_base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
if [ -d "$udd_base" ] && [ -w "$udd_base" ]; then
  printf '%s\n' "✓ user-data-dir base writable: $udd_base"
else
  printf '%s\n' "✗ user-data-dir base not writable: $udd_base"
  printf '%s\n' "  → Set XDG_RUNTIME_DIR or TMPDIR to a writable directory"
  failed=1
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
    if version_output=$("$chromium" --headless --no-sandbox --disable-gpu --dump-dom about:blank 2>&1); then
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
