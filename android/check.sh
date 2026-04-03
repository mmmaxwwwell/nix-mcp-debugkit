#!/usr/bin/env bash
set -euo pipefail

failed=0

# Check 1: adb binary on PATH and executable
if command -v adb >/dev/null 2>&1; then
  printf '%s\n' "✓ adb found: $(command -v adb)"
else
  printf '%s\n' "✗ adb not found on PATH"
  printf '%s\n' "  → Install android-tools or ensure adb is on PATH"
  failed=1
fi

# Check 2: adb devices — at least one connected device
if [ "$failed" -eq 0 ]; then
  device_lines=$(adb devices 2>/dev/null | tail -n +2 | grep -v '^$' || true)
  if [ -n "$device_lines" ]; then
    printf '%s\n' "✓ Connected devices:"
    while IFS= read -r line; do
      printf '%s\n' "  $line"
    done <<< "$device_lines"
  else
    printf '%s\n' "✗ No Android devices/emulators connected"
    printf '%s\n' "  → Start an emulator: emulator -avd <name> -no-window"
    failed=1
  fi
fi

exit "$failed"
