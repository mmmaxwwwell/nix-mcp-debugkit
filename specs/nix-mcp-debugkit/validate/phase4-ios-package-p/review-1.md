# Phase phase4-ios-package-p — Review #1: REVIEW-FIXES

**Date**: 2026-04-03
**Fixes applied**:
- `ios/default.nix`: `--check` flag was not intercepted by the wrapper — `mcp-ios --check` would pass the flag to the upstream node CLI instead of running `ios/check.sh`. Added check.sh installation to libexec and outer wrapper shim matching the pattern used by android and browser packages. Commit: ef017c4

**Deferred** (optional improvements, not bugs):
- None
