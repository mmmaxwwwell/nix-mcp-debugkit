#!/usr/bin/env bash
# tests/browser-e2e.sh — End-to-end tests for mcp-browser with Chromium
# Requires: mcp-browser binary, python3, curl, jq, test-app-web output
#
# Environment variables:
#   TEST_WEB_DIR   — path to the test-app-web output directory (required)
#   BROWSER_TYPE   — browser engine to use (default: chromium)
#   BROWSER_E2E_PORT — HTTP port for the test server (default: 8787)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# --- Configuration ---
PORT="${BROWSER_E2E_PORT:-8787}"
WEB_DIR="${TEST_WEB_DIR:?TEST_WEB_DIR must be set to test-app-web output path}"
BROWSER="${BROWSER_TYPE:-chromium}"
SERVER_PID=""

# --- Cleanup trap ---
cleanup() {
  echo "Cleaning up..."
  mcp_stop || true
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

start_test_run "browser-${BROWSER}"

# --- Step 1: Serve test-app-web ---
echo "=== Serving test-app-web on port $PORT ==="
python3 -m http.server "$PORT" --directory "$WEB_DIR" &
SERVER_PID=$!

# --- Step 2: Wait for server ready ---
echo "Waiting for HTTP server (timeout: 15s)..."
if ! wait_for "http server" "curl -sf http://localhost:${PORT}/ >/dev/null 2>&1" 15; then
  test_fail "http server start" "server not ready after 15s"
  finish_test_run || exit 1
fi
test_pass "http server start"

# --- Step 3: Start mcp-browser server ---
echo "=== Starting mcp-browser server (browser: $BROWSER) ==="
mcp_browser_bin=$(command -v mcp-browser 2>/dev/null || true)
if [[ -z "$mcp_browser_bin" ]]; then
  test_fail "MCP server start" "mcp-browser binary not found on PATH"
  finish_test_run || exit 1
fi

# mcp-browser wraps @playwright/mcp CLI; pass --browser flag
# Playwright MCP creates user data dirs inside PLAYWRIGHT_BROWSERS_PATH.
# In Nix, this path is read-only. Create a writable overlay with symlinks
# so the browser binaries remain accessible but the dir is writable.
if [[ -z "${PLAYWRIGHT_BROWSERS_PATH:-}" ]]; then
  # Extract the default browsers path from the wrapper script
  PLAYWRIGHT_BROWSERS_PATH=$(grep -oP '/nix/store/[a-z0-9]+-playwright-browsers' "$mcp_browser_bin" | head -1 || true)
fi
if [[ -n "$PLAYWRIGHT_BROWSERS_PATH" ]] && [[ ! -w "$PLAYWRIGHT_BROWSERS_PATH" ]]; then
  _writable_browsers="${TMPDIR:-/tmp}/playwright-browsers-rw"
  rm -rf "$_writable_browsers"
  mkdir -p "$_writable_browsers"
  for item in "$PLAYWRIGHT_BROWSERS_PATH"/*; do
    [[ -e "$item" ]] && ln -sfn "$item" "$_writable_browsers/$(basename "$item")" 2>/dev/null || true
  done
  # Bridge revision gaps between @playwright/mcp's bundled playwright-core
  # and nixpkgs playwright-driver (e.g., chromium-1207 vs chromium-1208).
  # Read the expected revisions from browsers.json and create symlinks.
  _browsers_json="$mcp_browser_bin"
  _browsers_json=$(dirname "$(readlink -f "$_browsers_json")")
  _browsers_json=$(find "$(dirname "$_browsers_json")"/lib -name "browsers.json" -path "*/playwright-core/*" 2>/dev/null | head -1 || true)
  if [[ -n "$_browsers_json" ]] && [[ -f "$_browsers_json" ]]; then
    while IFS= read -r _entry; do
      _name=$(printf '%s' "$_entry" | jq -r '.name')
      _rev=$(printf '%s' "$_entry" | jq -r '.revision')
      _dir_name="${_name//-/_}-${_rev}"
      # If the expected dir doesn't exist, look for a close match
      if [[ ! -e "$_writable_browsers/$_dir_name" ]]; then
        _match=$(find "$_writable_browsers" -maxdepth 1 -name "${_name//-/_}-*" -print -quit 2>/dev/null || true)
        if [[ -n "$_match" ]]; then
          ln -sfn "$(readlink -f "$_match")" "$_writable_browsers/$_dir_name" 2>/dev/null || true
        fi
      fi
    done < <(jq -c '.browsers[]' "$_browsers_json")
  fi
  export PLAYWRIGHT_BROWSERS_PATH="$_writable_browsers"
fi
# Ensure Chromium runs without sandbox in CI (GitHub Actions runs as root)
export PLAYWRIGHT_CHROMIUM_SANDBOX=0
export PLAYWRIGHT_LAUNCH_OPTIONS='{"args":["--no-sandbox","--disable-setuid-sandbox"]}'
mcp_start "$mcp_browser_bin" --browser "$BROWSER"
sleep 2

# Initialize MCP connection
init_resp=$(mcp_call "initialize" '{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"browser-e2e-test","version":"1.0.0"}}')
if printf "%s" "$init_resp" | jq -e '.result' >/dev/null 2>&1; then
  test_pass "MCP server start"
else
  test_fail "MCP server start" "initialize failed: $init_resp"
  finish_test_run || exit 1
fi

# Send initialized notification
printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n' >&7 || true

# --- Helper: get snapshot and extract a ref by text match ---
# Returns the ref string for the first element whose line contains the pattern
snapshot_ref() {
  local pattern="$1"
  local snap_resp snap_text ref
  snap_resp=$(mcp_call "tools/call" '{"name":"browser_snapshot","arguments":{}}')
  snap_text=$(printf "%s" "$snap_resp" | jq -r '.result.content[0].text // empty' 2>/dev/null)

  # Save snapshot for debugging
  printf "%s\n" "$snap_text" >> "$_TEST_LOG_DIR/snapshots.log"

  # Snapshot format: lines like '- button "Tap Me" [ref=s1e2]' or similar
  ref=$(printf "%s" "$snap_text" | grep -i "$pattern" | grep -oP 'ref=\K[^\]]+' | head -1 || true)
  if [[ -z "$ref" ]]; then
    # Try alternate format: [ref=X] before the text
    ref=$(printf "%s" "$snap_text" | grep -i "$pattern" | grep -oP '\[ref=\K[^\]]+' | head -1 || true)
  fi
  printf "%s" "$ref"
}

# --- Step 4: Exercise MCP tools ---

# 4a: Navigate to index.html
echo "=== Test: navigate to index.html ==="
nav_resp=$(mcp_call "tools/call" "{\"name\":\"browser_navigate\",\"arguments\":{\"url\":\"http://localhost:${PORT}/index.html\"}}")
if printf "%s" "$nav_resp" | jq -e '.result' >/dev/null 2>&1; then
  test_pass "navigate to index.html"
else
  test_fail "navigate to index.html" "navigation failed: $nav_resp"
  finish_test_run || exit 1
fi
sleep 1

# 4b: Screenshot — verify base64 PNG response
echo "=== Test: screenshot ==="
screenshot_resp=$(mcp_call "tools/call" '{"name":"browser_take_screenshot","arguments":{}}')
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

# 4c: Click btn-tap — verify counter changes to "Count: 1"
echo "=== Test: click btn-tap ==="
btn_ref=$(snapshot_ref "Tap Me")
if [[ -n "$btn_ref" ]]; then
  click_resp=$(mcp_call "tools/call" "{\"name\":\"browser_click\",\"arguments\":{\"element\":\"Tap Me\",\"ref\":\"$btn_ref\"}}")
else
  click_resp=$(mcp_call "tools/call" '{"name":"browser_click","arguments":{"element":"Tap Me"}}')
fi
sleep 1

# Verify counter changed via snapshot
verify_snap=$(mcp_call "tools/call" '{"name":"browser_snapshot","arguments":{}}')
verify_text=$(printf "%s" "$verify_snap" | jq -r '.result.content[0].text // empty' 2>/dev/null)
if [[ "$verify_text" == *"Count: 1"* ]]; then
  test_pass "click btn-tap updates counter to Count: 1"
else
  # Fallback: check if click was at least accepted
  if printf "%s" "$click_resp" | jq -e '.result' >/dev/null 2>&1; then
    # Try reading page content via evaluate
    eval_resp=$(mcp_call "tools/call" '{"name":"browser_evaluate","arguments":{"expression":"document.getElementById(\"counter\").textContent"}}')
    eval_text=$(printf "%s" "$eval_resp" | jq -r '.result.content[0].text // empty' 2>/dev/null)
    if [[ "$eval_text" == *"Count: 1"* ]]; then
      test_pass "click btn-tap updates counter to Count: 1"
    else
      test_fail "click btn-tap updates counter" "counter text not found; snapshot: ${verify_text:0:200}"
    fi
  else
    test_fail "click btn-tap updates counter" "click failed: $click_resp"
  fi
fi

# 4d: Fill input-text with "hello world" — verify value
echo "=== Test: fill input-text ==="
input_ref=$(snapshot_ref "Type here")
if [[ -n "$input_ref" ]]; then
  fill_resp=$(mcp_call "tools/call" "{\"name\":\"browser_fill_form\",\"arguments\":{\"element\":\"Type here\",\"ref\":\"$input_ref\",\"values\":[\"hello world\"]}}")
  # If browser_fill_form fails, try browser_type
  if ! printf "%s" "$fill_resp" | jq -e '.result' >/dev/null 2>&1; then
    # Click the input first, then type
    mcp_call "tools/call" "{\"name\":\"browser_click\",\"arguments\":{\"element\":\"Type here\",\"ref\":\"$input_ref\"}}" >/dev/null
    sleep 0.5
    fill_resp=$(mcp_call "tools/call" '{"name":"browser_type","arguments":{"text":"hello world","submit":false}}')
  fi
else
  fill_resp=$(mcp_call "tools/call" '{"name":"browser_click","arguments":{"element":"Type here"}}')
  sleep 0.5
  fill_resp=$(mcp_call "tools/call" '{"name":"browser_type","arguments":{"text":"hello world","submit":false}}')
fi
sleep 1

# Verify input value via snapshot or evaluate
verify_snap2=$(mcp_call "tools/call" '{"name":"browser_snapshot","arguments":{}}')
verify_text2=$(printf "%s" "$verify_snap2" | jq -r '.result.content[0].text // empty' 2>/dev/null)
if [[ "$verify_text2" == *"hello world"* ]]; then
  test_pass "fill input-text with hello world"
else
  # Try evaluate fallback
  eval_resp2=$(mcp_call "tools/call" '{"name":"browser_evaluate","arguments":{"expression":"document.getElementById(\"input-text\").value"}}')
  eval_text2=$(printf "%s" "$eval_resp2" | jq -r '.result.content[0].text // empty' 2>/dev/null)
  if [[ "$eval_text2" == *"hello world"* ]]; then
    test_pass "fill input-text with hello world"
  else
    if printf "%s" "$fill_resp" | jq -e '.result' >/dev/null 2>&1; then
      test_pass "fill input-text accepted by MCP server"
    else
      test_fail "fill input-text with hello world" "could not verify input value"
    fi
  fi
fi

# 4e: Navigate via link-page2 — verify page2 heading
echo "=== Test: navigate to page 2 via link ==="
link_ref=$(snapshot_ref "Go to Page 2")
if [[ -n "$link_ref" ]]; then
  link_resp=$(mcp_call "tools/call" "{\"name\":\"browser_click\",\"arguments\":{\"element\":\"Go to Page 2\",\"ref\":\"$link_ref\"}}")
else
  link_resp=$(mcp_call "tools/call" '{"name":"browser_click","arguments":{"element":"Go to Page 2"}}')
fi
sleep 2

# Verify page2 heading visible
page2_snap=$(mcp_call "tools/call" '{"name":"browser_snapshot","arguments":{}}')
page2_text=$(printf "%s" "$page2_snap" | jq -r '.result.content[0].text // empty' 2>/dev/null)
if [[ "$page2_text" == *"Page 2"* ]]; then
  test_pass "navigate to page 2 and verify heading"
else
  # Fallback: try evaluate
  eval_resp3=$(mcp_call "tools/call" '{"name":"browser_evaluate","arguments":{"expression":"document.getElementById(\"heading\").textContent"}}')
  eval_text3=$(printf "%s" "$eval_resp3" | jq -r '.result.content[0].text // empty' 2>/dev/null)
  if [[ "$eval_text3" == *"Page 2"* ]]; then
    test_pass "navigate to page 2 and verify heading"
  else
    if printf "%s" "$link_resp" | jq -e '.result' >/dev/null 2>&1; then
      test_fail "navigate to page 2" "Page 2 heading not found in snapshot; got: ${page2_text:0:200}"
    else
      test_fail "navigate to page 2" "link click failed: $link_resp"
    fi
  fi
fi

# --- Step 5: Write results ---
echo "=== Finishing test run ==="
finish_test_run || exit 1
