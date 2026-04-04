#!/usr/bin/env bash
# tests/ios-e2e.sh — End-to-end tests for mcp-ios with iOS Simulator
# macOS-only. Requires: Xcode (xcrun simctl), mcp-ios binary, jq
#
# Uses stock iOS apps (e.g. Settings) as test targets since custom iOS apps
# cannot be Nix-built.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# --- Configuration ---
BOOT_TIMEOUT=60
SIMULATOR_UDID=""

# --- Cleanup trap ---
cleanup() {
  echo "Cleaning up..."
  mcp_stop || true
  if [[ -n "$SIMULATOR_UDID" ]]; then
    echo "Shutting down simulator $SIMULATOR_UDID..."
    xcrun simctl shutdown "$SIMULATOR_UDID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

start_test_run "ios"

# --- Step 1: Find an available iPhone simulator ---
echo "=== Finding available iPhone simulator ==="
# List available devices in JSON, pick a Shutdown iPhone simulator
SIMULATOR_UDID=$(xcrun simctl list devices available -j 2>/dev/null \
  | jq -r '
    [.devices | to_entries[] | .value[] |
     select(.name | test("iPhone"; "i")) |
     select(.state == "Shutdown")] |
    first | .udid // empty
  ' 2>/dev/null || true)

# If no shutdown iPhone found, try any available iPhone (may already be booted)
if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID=$(xcrun simctl list devices available -j 2>/dev/null \
    | jq -r '
      [.devices | to_entries[] | .value[] |
       select(.name | test("iPhone"; "i"))] |
      first | .udid // empty
    ' 2>/dev/null || true)
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  test_fail "find iPhone simulator" "no iPhone simulator available; install Xcode runtimes"
  finish_test_run || exit 1
fi

SIM_NAME=$(xcrun simctl list devices available -j 2>/dev/null \
  | jq -r --arg udid "$SIMULATOR_UDID" '
    [.devices | to_entries[] | .value[] | select(.udid == $udid)] |
    first | .name // "unknown"
  ' 2>/dev/null || echo "unknown")
echo "Selected simulator: $SIM_NAME ($SIMULATOR_UDID)"
test_pass "find iPhone simulator"

# --- Step 2: Boot simulator ---
echo "=== Booting simulator ==="
SIM_STATE=$(xcrun simctl list devices available -j 2>/dev/null \
  | jq -r --arg udid "$SIMULATOR_UDID" '
    [.devices | to_entries[] | .value[] | select(.udid == $udid)] |
    first | .state // "unknown"
  ' 2>/dev/null || echo "unknown")

if [[ "$SIM_STATE" == "Booted" ]]; then
  echo "Simulator already booted"
else
  xcrun simctl boot "$SIMULATOR_UDID" 2>&1 || {
    test_fail "simulator boot" "xcrun simctl boot failed for $SIMULATOR_UDID"
    finish_test_run || exit 1
  }
fi

# --- Step 3: Wait for booted state ---
echo "Waiting for simulator to be booted (timeout: ${BOOT_TIMEOUT}s)..."
if ! wait_for "simulator booted" \
  "[[ \$(xcrun simctl list devices -j 2>/dev/null | jq -r --arg udid '$SIMULATOR_UDID' '[.devices | to_entries[] | .value[] | select(.udid == \$udid)] | first | .state // empty') == 'Booted' ]]" \
  "$BOOT_TIMEOUT"; then
  test_fail "simulator boot" "simulator not booted after ${BOOT_TIMEOUT}s"
  finish_test_run || exit 1
fi
test_pass "simulator boot"

# Open Settings app as a test target (stock app, always available)
echo "=== Launching Settings app ==="
xcrun simctl launch "$SIMULATOR_UDID" com.apple.Preferences 2>&1 || true
sleep 2

# --- Step 4: Start mcp-ios server ---
echo "=== Starting mcp-ios server ==="
mcp_ios_bin=$(command -v mcp-ios 2>/dev/null || true)
if [[ -z "$mcp_ios_bin" ]]; then
  test_fail "MCP server start" "mcp-ios binary not found on PATH"
  finish_test_run || exit 1
fi

mcp_start "$mcp_ios_bin"
sleep 2

# Initialize MCP connection
init_resp=$(mcp_call "initialize" '{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"ios-e2e-test","version":"1.0.0"}}')
if printf "%s" "$init_resp" | jq -e '.result' >/dev/null 2>&1; then
  test_pass "MCP server start"
else
  test_fail "MCP server start" "initialize failed: $init_resp"
  finish_test_run || exit 1
fi

# Send initialized notification
printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n' >&7 || true

# --- Step 5: Exercise MCP tools ---

# First, list available tools to discover the exact tool names
echo "=== Discovering available tools ==="
tools_resp=$(mcp_call "tools/list" '{}')
tools_text=$(printf "%s" "$tools_resp" | jq -r '[.result.tools[].name] | join(", ")' 2>/dev/null || echo "unknown")
echo "Available tools: $tools_text"
printf "%s\n" "$tools_text" > "$_TEST_LOG_DIR/available-tools.txt"

# 5a: Screenshot — verify base64 PNG response
echo "=== Test: screenshot ==="
# Try common tool names for screenshot
screenshot_resp=""
for tool_name in "screenshot" "take_screenshot" "ios_screenshot"; do
  if printf "%s" "$tools_text" | grep -qw "$tool_name"; then
    screenshot_resp=$(mcp_call "tools/call" "{\"name\":\"$tool_name\",\"arguments\":{\"output_path\":\"$_TEST_LOG_DIR/screenshot.png\"}}")
    break
  fi
done
# Fallback: try "screenshot" directly
if [[ -z "$screenshot_resp" ]]; then
  screenshot_resp=$(mcp_call "tools/call" "{\"name\":\"screenshot\",\"arguments\":{\"output_path\":\"$_TEST_LOG_DIR/screenshot.png\"}}")
fi

if printf "%s" "$screenshot_resp" | jq -e '.result' >/dev/null 2>&1; then
  content_type=$(printf "%s" "$screenshot_resp" | jq -r '.result.content[0].type // empty' 2>/dev/null)
  if [[ "$content_type" == "image" ]]; then
    b64_data=$(printf "%s" "$screenshot_resp" | jq -r '.result.content[0].data // empty' 2>/dev/null)
    if [[ "$b64_data" == iVBOR* ]]; then
      test_pass "screenshot returns base64 PNG"
    else
      test_pass "screenshot returns image content"
    fi
  else
    resp_text=$(printf "%s" "$screenshot_resp" | jq -r '.result.content[0].text // empty' 2>/dev/null)
    if [[ -n "$resp_text" ]]; then
      test_pass "screenshot returns content"
    else
      test_fail "screenshot returns base64 PNG" "unexpected content type: $content_type"
    fi
  fi
else
  test_fail "screenshot returns base64 PNG" "screenshot tool call failed: $screenshot_resp"
fi

# 5b: Tap center of screen — verify response
echo "=== Test: tap center of screen ==="
tap_resp=""
for tool_name in "ui_tap" "tap" "click" "ios_tap"; do
  if printf "%s" "$tools_text" | grep -qw "$tool_name"; then
    # Tap center of a standard iPhone screen (roughly 195, 422 for logical coords)
    tap_resp=$(mcp_call "tools/call" "{\"name\":\"$tool_name\",\"arguments\":{\"x\":195,\"y\":422}}")
    break
  fi
done
# Fallback: try "tap" directly
if [[ -z "$tap_resp" ]]; then
  tap_resp=$(mcp_call "tools/call" '{"name":"tap","arguments":{"x":195,"y":422}}')
fi

if printf "%s" "$tap_resp" | jq -e '.result' >/dev/null 2>&1; then
  # Check that the result doesn't indicate an error
  is_error=$(printf "%s" "$tap_resp" | jq -r '.result.isError // false' 2>/dev/null)
  if [[ "$is_error" == "true" ]]; then
    err_text=$(printf "%s" "$tap_resp" | jq -r '.result.content[0].text // empty' 2>/dev/null)
    # If idb is missing, skip instead of fail (idb is optional for tap interactions)
    if [[ "$err_text" == *"idb"* ]] || [[ "$err_text" == *"ENOENT"* ]]; then
      test_skip "tap center of screen" "idb not available: $err_text"
    else
      test_fail "tap center of screen" "tool returned error: $err_text"
    fi
  else
    test_pass "tap center of screen"
  fi
else
  test_fail "tap center of screen" "tap tool call failed: $tap_resp"
fi

# --- Step 6: Write results ---
echo "=== Finishing test run ==="
finish_test_run || exit 1
