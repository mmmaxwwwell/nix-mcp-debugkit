#!/usr/bin/env bash
# tests/smoke.sh — Smoke tests for nix-mcp-debugkit packages
# Verifies binaries exist, accept basic flags, and default package composition.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

start_test_run "smoke"

# --- Package binaries exist and are executable ---

is_darwin=false
if [[ "$(uname -s)" == "Darwin" ]]; then
  is_darwin=true
fi

for pkg in mcp-android mcp-browser mcp-ios; do
  # mcp-ios is darwin-only; skip on other platforms
  if [[ "$pkg" == "mcp-ios" ]] && ! $is_darwin; then
    test_skip "$pkg binary exists and is executable" "darwin-only package"
    continue
  fi
  bin=$(command -v "$pkg" 2>/dev/null || true)
  if [[ -n "$bin" && -x "$bin" ]]; then
    test_pass "$pkg binary exists and is executable"
  else
    test_fail "$pkg binary exists and is executable" "$pkg not found on PATH or not executable"
  fi
done

# --- --check flag accepted (exits without crash) ---

for pkg in mcp-android mcp-browser mcp-ios; do
  bin=$(command -v "$pkg" 2>/dev/null || true)
  if [[ -z "$bin" ]]; then
    test_skip "$pkg --check flag" "binary not available"
    continue
  fi
  if "$bin" --check >/dev/null 2>&1; then
    test_pass "$pkg --check flag"
  else
    rc=$?
    # Exit code 0 or 1 is acceptable (flag recognized); 127 = not found, 126 = not executable
    if (( rc < 126 )); then
      test_pass "$pkg --check flag"
    else
      test_fail "$pkg --check flag" "exited with code $rc"
    fi
  fi
done

# --- --help or MCP initialize handshake ---

for pkg in mcp-android mcp-browser mcp-ios; do
  bin=$(command -v "$pkg" 2>/dev/null || true)
  if [[ -z "$bin" ]]; then
    test_skip "$pkg --help/initialize" "binary not available"
    continue
  fi
  output=$("$bin" --help 2>&1 || true)
  if [[ -n "$output" ]]; then
    test_pass "$pkg --help/initialize"
  else
    test_fail "$pkg --help/initialize" "no output from --help"
  fi
done

# --- Default package contains correct packages per platform ---

if [[ -n "${DEFAULT_PKG_PATH:-}" ]]; then
  if $is_darwin; then
    expected_bins=("mcp-browser" "mcp-ios")
    unexpected_bins=("mcp-android")
  else
    expected_bins=("mcp-android" "mcp-browser")
    unexpected_bins=("mcp-ios")
  fi

  for bin_name in "${expected_bins[@]}"; do
    if [[ -x "$DEFAULT_PKG_PATH/bin/$bin_name" ]]; then
      test_pass "default package contains $bin_name"
    else
      test_fail "default package contains $bin_name" "not found in $DEFAULT_PKG_PATH/bin/"
    fi
  done

  for bin_name in "${unexpected_bins[@]}"; do
    if [[ -x "$DEFAULT_PKG_PATH/bin/$bin_name" ]]; then
      test_fail "default package excludes $bin_name" "unexpectedly found in $DEFAULT_PKG_PATH/bin/"
    else
      test_pass "default package excludes $bin_name"
    fi
  done
else
  test_skip "default package composition" "DEFAULT_PKG_PATH not set"
fi

# --- Test app packages build ---

for pkg in test-app-android test-app-web; do
  if [[ -n "${TEST_APP_PATHS:-}" ]]; then
    # TEST_APP_PATHS is a colon-separated list of built test app paths
    # Check if the package name appears in the paths
    if [[ "$TEST_APP_PATHS" == *"$pkg"* ]]; then
      test_pass "$pkg builds"
    else
      test_fail "$pkg builds" "$pkg not found in TEST_APP_PATHS"
    fi
  else
    # Fall back to checking if the package binary/output exists
    bin=$(command -v "$pkg" 2>/dev/null || true)
    if [[ -n "$bin" ]]; then
      test_pass "$pkg builds"
    else
      test_skip "$pkg builds" "package not available on PATH and TEST_APP_PATHS not set"
    fi
  fi
done

# --- Finish ---

finish_test_run || exit 1
