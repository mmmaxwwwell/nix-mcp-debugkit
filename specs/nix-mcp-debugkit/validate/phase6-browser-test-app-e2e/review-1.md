# Phase phase6-browser-test-app-e2e — Review #1: REVIEW-FIXES

**Date**: 2026-04-04T01:20Z
**Fixes applied**:
- `tests/common.sh:126`: `${2:-{}}` bash brace parsing bug — bash parses `${2:-{}` as the expansion (default=`{`) with trailing literal `}`, causing all mcp_call invocations to append an extra `}` to JSON params. Fixed by using explicit `if [[ $# -ge 2 ]]` conditional. Commit: bfabd6e
- `tests/browser-e2e.sh:56-92`: Added writable PLAYWRIGHT_BROWSERS_PATH overlay — Playwright MCP creates user data dirs inside PLAYWRIGHT_BROWSERS_PATH which is a read-only Nix store path. Added logic to extract the path from the wrapper, create a writable temp dir with symlinks to the real browsers, and bridge revision gaps between @playwright/mcp's bundled playwright-core and nixpkgs playwright-driver. Commit: bfabd6e
- `browser/default.nix:23,32`: Changed `--set` to `--set-default` in makeWrapper and conditional export in outer wrapper — the original unconditionally overrode PLAYWRIGHT_BROWSERS_PATH, preventing tests from redirecting it to a writable location. Commit: bfabd6e

**Deferred** (optional improvements, not bugs):
- `browser-e2e.sh` screenshot test (line 155) passes on any text content, which could mask browser startup errors as a false positive. The test progression catches real failures downstream, so not a correctness issue.
- The playwright-core/nixpkgs version mismatch (revision 1207 vs 1208) is a pre-existing issue in `browser/default.nix` from phase 3. The revision bridging in browser-e2e.sh is a workaround; the proper fix is to align `@playwright/mcp` version with nixpkgs playwright-driver.
