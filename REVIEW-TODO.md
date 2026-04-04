# Code Review — nix-mcp-debugkit

Reviewer: REVIEW task (Phase 11 Final Validation)
Date: 2026-04-04

## Summary

Overall the codebase is well-structured and production-quality. All linters pass clean (statix, deadnix, shellcheck). No hardcoded secrets found. Test infrastructure is thorough with structured JSON output.

## Findings

### MEDIUM — Fix Required

#### M1: `snyk/actions/setup@master` not version-pinned (ci.yml:329)
**Category**: Security / Supply chain
**Issue**: The Snyk setup action uses `@master` which tracks a moving branch. All other actions use version tags. A compromised upstream push to `master` could inject malicious code.
**Fix**: Pin to `@0.4.0` (latest stable tag).

#### M2: Dependabot still disabled (.github/dependabot.yml)
**Category**: Security / Dependency management
**Issue**: Comment says "Re-enable once T030 is complete" — T030 is complete. Dependabot should be enabled for npm (browser, ios) and GitHub Actions ecosystems. The `ios-simulator-mcp` SDK ignore rule from learnings should be included.
**Fix**: Enable dependabot with proper update schedules and the known ignore rule.

#### M3: CI shellcheck only covers tests/*.sh (ci.yml:22)
**Category**: Quality / Lint coverage
**Issue**: `shellcheck --severity=warning tests/*.sh` misses `scripts/security-scan.sh`, `android/check.sh`, `browser/check.sh`, `ios/check.sh`. These scripts pass shellcheck locally but aren't validated in CI.
**Fix**: Add the missing script paths to the CI shellcheck step.

### LOW — Acceptable / Documented

#### L1: Inconsistent cachix/install-nix-action versions (ci.yml)
**Category**: Consistency
**Issue**: Linux jobs use `@v27`, macOS uses `@v30`. The upgrade to `@v30` on macOS was needed to fix `nixbld` user conflicts. Linux jobs work fine with `@v27`.
**Decision**: Upgrade all to `@v30` for consistency.

#### L2: `eval "$cmd"` in common.sh wait_for() (common.sh:201)
**Category**: Shell safety
**Issue**: Uses `eval` on a string parameter. All call sites pass hardcoded string literals (no user input). Risk is minimal in test-only code.
**Decision**: No fix needed. All callers are trusted, hardcoded commands.

#### L3: security-scan.sh fallback SARIF is minimal (security-scan.sh:36,52,68)
**Category**: Correctness
**Issue**: Local script fallback SARIF `{"runs":[{"results":[]}]}` lacks `$schema`/`version`/`tool.driver` fields that GitHub SARIF upload requires. CI workflow has the full format.
**Decision**: No fix needed. This script is local-only; CI has correct fallback SARIF.

### INFO — No Action Required

#### I1: continue-on-error on WebKit/iOS steps
Documented workaround for upstream issues (WebKit incomplete page snapshots, fb-idb deprecation). Verification steps enforce minimum pass thresholds.

#### I2: test_skip function defined but never called
The function exists in common.sh but is intentionally unused — the skip-as-failure policy (common.sh:68) means tests should either run or be removed, never skipped.

#### I3: No CLAUDE.md file
Project has no CLAUDE.md for build/test conventions. PROJECT.md exists but isn't the standard convention file.

## Applied Fixes

- [x] M1: Pin snyk/actions/setup to @0.4.0
- [x] M2: Enable dependabot with npm and github-actions ecosystems
- [x] M3: Expand CI shellcheck to cover all .sh files
- [x] L1: Upgrade all cachix/install-nix-action to @v30
