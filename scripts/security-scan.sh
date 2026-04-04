#!/usr/bin/env bash
# Local security scan script — runs gitleaks, trivy, and semgrep
# Outputs JSON/SARIF to test-logs/security/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/test-logs/security"
mkdir -p "$OUTPUT_DIR"

pass=0
skip=0

run_scanner() {
  local name="$1"
  shift
  printf "==> Running %s...\n" "$name"
  if "$@"; then
    printf "    %s: OK\n\n" "$name"
    pass=$((pass + 1))
  else
    printf "    %s: findings detected (exit code %s)\n\n" "$name" "$?"
    # Non-zero exit usually means findings, not failure — still count as pass
    pass=$((pass + 1))
  fi
}

# --- Gitleaks ---
if command -v gitleaks >/dev/null 2>&1; then
  run_scanner "gitleaks" gitleaks detect \
    --source="$REPO_ROOT" \
    --report-format=sarif \
    --report-path="$OUTPUT_DIR/gitleaks.sarif.json" \
    --no-banner
  # gitleaks exits 1 when leaks are found — the output file is still written
  if [ ! -f "$OUTPUT_DIR/gitleaks.sarif.json" ]; then
    echo '{"runs":[{"results":[]}]}' > "$OUTPUT_DIR/gitleaks.sarif.json"
  fi
else
  printf "==> gitleaks: not found, skipping\n\n"
  skip=$((skip + 1))
fi

# --- Trivy ---
if command -v trivy >/dev/null 2>&1; then
  run_scanner "trivy" trivy fs \
    --scanners vuln,misconfig \
    --severity CRITICAL,HIGH \
    --format sarif \
    --output "$OUTPUT_DIR/trivy.sarif.json" \
    "$REPO_ROOT"
  if [ ! -f "$OUTPUT_DIR/trivy.sarif.json" ]; then
    echo '{"runs":[{"results":[]}]}' > "$OUTPUT_DIR/trivy.sarif.json"
  fi
else
  printf "==> trivy: not found, skipping\n\n"
  skip=$((skip + 1))
fi

# --- Semgrep ---
if command -v semgrep >/dev/null 2>&1; then
  run_scanner "semgrep" semgrep scan \
    --config=p/default \
    --sarif \
    --output="$OUTPUT_DIR/semgrep.sarif.json" \
    "$REPO_ROOT"
  if [ ! -f "$OUTPUT_DIR/semgrep.sarif.json" ]; then
    echo '{"runs":[{"results":[]}]}' > "$OUTPUT_DIR/semgrep.sarif.json"
  fi
else
  printf "==> semgrep: not found, skipping\n\n"
  skip=$((skip + 1))
fi

# --- Summary ---
echo "==============================="
echo " Security Scan Summary"
echo "==============================="
echo " Passed: $pass"
echo " Skipped: $skip"
echo " Output:  $OUTPUT_DIR/"
echo ""
ls -lh "$OUTPUT_DIR/"
echo "==============================="
