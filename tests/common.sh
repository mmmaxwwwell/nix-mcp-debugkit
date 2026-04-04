#!/usr/bin/env bash
# tests/common.sh — Shared test utilities for nix-mcp-debugkit
# Provides structured test output, MCP helpers, and assertions.

set -euo pipefail

# --- State ---
_TEST_TARGET=""
_TEST_LOG_DIR=""
_TEST_PASS=0
_TEST_FAIL=0
_TEST_SKIP=0
_TEST_RESULTS="[]"
_MCP_PID=""
_MCP_STDIN=""
_MCP_STDOUT=""
_JSONRPC_ID=0

# --- Test lifecycle ---

start_test_run() {
  local target="${1:?start_test_run requires a target name}"
  _TEST_TARGET="$target"
  _TEST_LOG_DIR="test-logs/${target}"
  _TEST_PASS=0
  _TEST_FAIL=0
  _TEST_SKIP=0
  _TEST_RESULTS="[]"
  mkdir -p "$_TEST_LOG_DIR"
}

test_pass() {
  local name="${1:?test_pass requires a test name}"
  (( _TEST_PASS++ )) || true
  _TEST_RESULTS=$(_jq_append "$_TEST_RESULTS" \
    "{\"name\":$(json_str "$name"),\"status\":\"pass\"}")
  printf "  PASS: %s\n" "$name"
}

test_fail() {
  local name="${1:?test_fail requires a test name}"
  local details="${2:-}"
  (( _TEST_FAIL++ )) || true
  _TEST_RESULTS=$(_jq_append "$_TEST_RESULTS" \
    "{\"name\":$(json_str "$name"),\"status\":\"fail\",\"details\":$(json_str "$details")}")
  printf "  FAIL: %s — %s\n" "$name" "$details" >&2
}

test_skip() {
  local name="${1:?test_skip requires a test name}"
  local reason="${2:-}"
  (( _TEST_SKIP++ )) || true
  _TEST_RESULTS=$(_jq_append "$_TEST_RESULTS" \
    "{\"name\":$(json_str "$name"),\"status\":\"skip\",\"reason\":$(json_str "$reason")}")
  printf "  SKIP: %s — %s\n" "$name" "$reason"
}

finish_test_run() {
  local total=$(( _TEST_PASS + _TEST_FAIL + _TEST_SKIP ))

  # Non-vacuous check: at least one pass or fail required
  if (( _TEST_PASS + _TEST_FAIL == 0 )); then
    printf "ERROR: vacuous test run (0 pass + 0 fail) for target '%s'\n" "$_TEST_TARGET" >&2
    exit 1
  fi

  # Skip-as-failure check: skipped tests mean a broken environment
  if (( _TEST_SKIP > 0 )); then
    printf "ERROR: %d test(s) skipped for target '%s' — skips are treated as failures\n" "$_TEST_SKIP" "$_TEST_TARGET" >&2
    printf "If a test cannot run on this platform, remove it from the test list instead of skipping.\n" >&2
    return 1
  fi

  local summary
  summary=$(cat <<ENDJSON
{
  "target": $(json_str "$_TEST_TARGET"),
  "pass": $_TEST_PASS,
  "fail": $_TEST_FAIL,
  "skip": $_TEST_SKIP,
  "total": $total,
  "results": $_TEST_RESULTS
}
ENDJSON
)

  printf "%s\n" "$summary" > "$_TEST_LOG_DIR/summary.json"
  printf "Results: %d pass, %d fail, %d skip (total %d) — %s\n" \
    "$_TEST_PASS" "$_TEST_FAIL" "$_TEST_SKIP" "$total" "$_TEST_LOG_DIR/summary.json"

  if (( _TEST_FAIL > 0 )); then
    return 1
  fi
  return 0
}

# --- MCP helpers ---

mcp_start() {
  local binary="${1:?mcp_start requires a binary path}"
  shift
  local stdin_fifo stdout_fifo
  stdin_fifo=$(mktemp -u /tmp/mcp_stdin.XXXXXX)
  stdout_fifo=$(mktemp -u /tmp/mcp_stdout.XXXXXX)
  mkfifo "$stdin_fifo"
  mkfifo "$stdout_fifo"

  "$binary" "$@" < "$stdin_fifo" > "$stdout_fifo" 2>/dev/null &
  _MCP_PID=$!
  _MCP_STDIN="$stdin_fifo"
  _MCP_STDOUT="$stdout_fifo"

  # Open file descriptors for writing/reading
  exec 7>"$stdin_fifo"
  exec 8<"$stdout_fifo"
}

mcp_stop() {
  if [[ -n "$_MCP_PID" ]]; then
    exec 7>&- 2>/dev/null || true
    exec 8<&- 2>/dev/null || true
    kill "$_MCP_PID" 2>/dev/null || true
    wait "$_MCP_PID" 2>/dev/null || true
    rm -f "$_MCP_STDIN" "$_MCP_STDOUT"
    _MCP_PID=""
    _MCP_STDIN=""
    _MCP_STDOUT=""
  fi
}

mcp_call() {
  local method="${1:?mcp_call requires a method}"
  local params
  if [[ $# -ge 2 ]]; then
    params="$2"
  else
    params='{}'
  fi
  (( _JSONRPC_ID++ )) || true

  local request
  request=$(printf '{"jsonrpc":"2.0","id":%d,"method":%s,"params":%s}\n' \
    "$_JSONRPC_ID" "$(json_str "$method")" "$params")

  printf "%s\n" "$request" >&7
  local response
  read -r response <&8
  printf "%s" "$response"
}

# --- Assertions ---

assert_json() {
  local json="${1:?assert_json requires json}"
  local jq_expr="${2:?assert_json requires a jq expression}"
  local expected="${3:?assert_json requires an expected value}"

  local actual
  actual=$(printf "%s" "$json" | jq -r "$jq_expr" 2>/dev/null) || {
    printf "assert_json: jq expression failed: %s\n" "$jq_expr" >&2
    return 1
  }

  if [[ "$actual" != "$expected" ]]; then
    printf "assert_json: expected %s for '%s', got %s\n" "$expected" "$jq_expr" "$actual" >&2
    return 1
  fi
}

assert_eq() {
  local actual="${1?assert_eq requires actual}"
  local expected="${2?assert_eq requires expected}"
  local msg="${3:-assert_eq}"

  if [[ "$actual" != "$expected" ]]; then
    printf "%s: expected '%s', got '%s'\n" "$msg" "$expected" "$actual" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="${1?assert_contains requires haystack}"
  local needle="${2?assert_contains requires needle}"
  local msg="${3:-assert_contains}"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf "%s: '%s' not found in '%s'\n" "$msg" "$needle" "$haystack" >&2
    return 1
  fi
}

# --- Utilities ---

wait_for() {
  local name="${1:?wait_for requires a name}"
  local cmd="${2:?wait_for requires a command}"
  local timeout="${3:-30}"

  local elapsed=0
  while (( elapsed < timeout )); do
    if eval "$cmd" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    (( elapsed++ )) || true
  done

  printf "wait_for '%s': timed out after %ds\n" "$name" "$timeout" >&2
  return 1
}

# JSON string escaper (no external deps beyond bash builtins)
json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  printf '"%s"' "$s"
}

# Append an element to a JSON array using jq
_jq_append() {
  local arr="$1"
  local elem="$2"
  printf "%s" "$arr" | jq -c ". + [$elem]"
}
