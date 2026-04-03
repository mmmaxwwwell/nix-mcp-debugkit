# Phase phase1-flake-scaffold-test- — Review #1: REVIEW-FIXES

**Date**: 2026-04-03
**Fixes applied**:
- `flake.nix:84`: Smoke check derivation used `cd ${./tests}` which resolves to a read-only Nix store path, causing `mkdir test-logs` to fail with "Permission denied". Fixed by copying test files to `$TMPDIR` before running. Commit: 4f3aa67

**Deferred** (optional improvements, not bugs):
- statix W04: overlay assignments could use `inherit` syntax instead of explicit assignment — style preference, no functional impact
- deadnix: unused `final` argument in `overlays.default = final: prev:` — standard Nix overlay convention, not dead code
- `shellcheck` is included in smoke check `nativeBuildInputs` but never used during the smoke test run — harmless, may be useful for future checks
