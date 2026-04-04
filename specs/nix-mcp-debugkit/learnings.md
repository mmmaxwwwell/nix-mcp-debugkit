# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

- `fetchPypi` uses the old `/packages/source/` URL scheme which 404s for some PyPI packages (e.g., `android-mcp`). Use `fetchurl` with the direct hashed PyPI URL instead.
- `pyproject = false` in recent nixpkgs-unstable may not correctly select setuptools build hooks; use `format = "setuptools"` explicitly for pbr/setuptools packages.
- Scripts created in `postFixup` (after Nix's automatic shebang patching and after `wrapProgram`) must use Nix store bash paths (`${pkgs.bash}/bin/bash`) instead of `#!/usr/bin/env bash` — the Nix build sandbox lacks `/usr/bin/env`. `patchShebangs` in postFixup does NOT work on these files.

- T013 made mcp-ios darwin-only in flake.nix but the smoke test's "binary exists" loop used `test_fail` for missing binaries. The `--check` and `--help` loops already handled missing binaries with `test_skip`, but the first loop needed an explicit platform check to skip mcp-ios on non-darwin instead of failing.

## phase2-android-package-p-fix1 — Fix phase validation
- `config.android_sdk.accept_license = true` is NOT sufficient for Nix flake/pure evaluation — it only controls the Android SDK's internal license check. You also need `config.allowUnfree = true` (or a targeted `allowUnfreePredicate`) in the nixpkgs import config to prevent Nix from refusing to evaluate the `androidsdk` derivation.

## phase4-ios-package-p-fix1 — Smoke test platform skip
## phase5-android-test-app-e2e-fix1 — Unfree license fix
## T023 — .github/workflows/ci.yml
- GitHub Actions KVM access on ubuntu-latest requires a udev rule (`KERNEL=="kvm"` with MODE 0666) + udevadm reload/trigger — just `sudo chmod` on `/dev/kvm` is not persistent across steps.
- `browser-e2e-all.sh` produces `test-logs/browser-{firefox,webkit}/summary.json` (hyphenated prefix), while `browser-e2e.sh` produces `test-logs/browser/summary.json` — verify paths match when writing non-vacuous checks.

## T024 — Gitleaks pre-commit hook
- Used `.githooks/pre-commit` + `git config core.hooksPath .githooks` (via shellHook) instead of the Python `pre-commit` framework — simpler, no extra dependency.
- `AKIAIOSFODNN7EXAMPLE` is in gitleaks' built-in allowlist (AWS documentation example key). Use a non-example key like `wJalrXUtnFEMI/K7MDENG/bPxRfiCYSECRETKEY1` when testing detection.

## phase8-ci-pipeline-fix1 — CI shellcheck severity
- `shellcheck` exits non-zero on info-level SC1091 (`source "$VAR/file"` not followed). CI must use `--severity=warning` to avoid false failures on runtime-variable source paths.

## T025 — Security scan jobs in CI
- `gitleaks/gitleaks-action@v2` uses `args` input (not CLI flags) and requires `GITLEAKS_LICENSE` secret for org repos; use `continue-on-error: true` for graceful degradation without the license.
- Semgrep in CI runs best via `container: image: semgrep/semgrep` rather than installing the binary — avoids Python version conflicts and is the official recommended approach.
- All SARIF upload steps need `permissions: security-events: write` on the job and a fallback to generate a minimal valid SARIF (`{"runs":[{"results":[]}]}`) when the scanner produces no output file.
