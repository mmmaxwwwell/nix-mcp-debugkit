# Phase phase7-ios-e2e — Review #1: REVIEW-FIXES

**Date**: 2026-04-04T01:30Z

**Scope**: 4 files changed, +221/-16 lines | **Base**: 7c8f30e~1
**Commits**: T021 (ios-e2e.sh script), T022 (wire into flake.nix checks)

**Fixes applied**:
- `specs/nix-mcp-debugkit/learnings.md`: Restored accidentally deleted T014, T015, T016 learnings sections and fixed phase4-ios-package-p-fix1 content that was moved under the wrong heading (phase2 instead of phase4). Commit: 1e01ba3

**Deferred** (optional improvements, not bugs):
- The cleanup trap will shut down a simulator even if it was already booted before the script ran. In a Nix sandbox context this is fine; for local developer runs it could be slightly disruptive. Not a bug.
- SC1091 shellcheck info about not following sourced `common.sh` — affects all test scripts equally, not specific to this phase.
