#!/usr/bin/env bash
set -euo pipefail

failed=0

# Check 1: xcrun simctl is available (Xcode CLI tools installed)
if xcrun simctl list devices >/dev/null 2>&1; then
  printf '%s\n' "✓ Xcode CLI tools available (xcrun simctl)"
else
  printf '%s\n' "✗ Xcode CLI tools not found"
  printf '%s\n' "  → Install with: xcode-select --install"
  failed=1
fi

# Check 2: at least one simulator exists
if [ "$failed" -eq 0 ]; then
  # List booted + shutdown devices, skip headers and empty lines
  sim_lines=$(xcrun simctl list devices available 2>/dev/null | grep -E '^\s+\S' || true)
  if [ -n "$sim_lines" ]; then
    printf '%s\n' "✓ Simulators available:"
    while IFS= read -r line; do
      printf '%s\n' "  $line"
    done <<< "$sim_lines"
  else
    printf '%s\n' "✗ No simulators found"
    printf '%s\n' "  → Create one with: xcrun simctl create <name> <device-type> <runtime>"
    failed=1
  fi
fi

exit "$failed"
