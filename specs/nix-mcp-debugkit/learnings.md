# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

- `fetchPypi` uses the old `/packages/source/` URL scheme which 404s for some PyPI packages (e.g., `android-mcp`). Use `fetchurl` with the direct hashed PyPI URL instead.
- `pyproject = false` in recent nixpkgs-unstable may not correctly select setuptools build hooks; use `format = "setuptools"` explicitly for pbr/setuptools packages.
- Scripts created in `postFixup` (after Nix's automatic shebang patching and after `wrapProgram`) must use Nix store bash paths (`${pkgs.bash}/bin/bash`) instead of `#!/usr/bin/env bash` — the Nix build sandbox lacks `/usr/bin/env`. `patchShebangs` in postFixup does NOT work on these files.

- T013 made mcp-ios darwin-only in flake.nix but the smoke test's "binary exists" loop used `test_fail` for missing binaries. The `--check` and `--help` loops already handled missing binaries with `test_skip`, but the first loop needed an explicit platform check to skip mcp-ios on non-darwin instead of failing.

## phase2-android-package-p-fix1 — Fix phase validation
## phase4-ios-package-p-fix1 — Smoke test platform skip
- `config.android_sdk.accept_license = true` is NOT sufficient for Nix flake/pure evaluation — it only controls the Android SDK's internal license check. You also need `config.allowUnfree = true` (or a targeted `allowUnfreePredicate`) in the nixpkgs import config to prevent Nix from refusing to evaluate the `androidsdk` derivation.

## phase5-android-test-app-e2e-fix1 — Unfree license fix
## T021 — tests/ios-e2e.sh (iOS Simulator E2E)
- `ios-simulator-mcp` (v1.5.2) is the upstream package. Tool names are discovered at runtime via `tools/list` since they may vary across versions — the script probes for common names like `screenshot`, `take_screenshot`, `tap`, `click`.
- `xcrun simctl list devices available -j` gives JSON output; use `jq` to pick an iPhone simulator by name pattern and state, avoiding fragile text parsing.
- Stock iOS apps (e.g. `com.apple.Preferences`) serve as test targets since custom iOS apps can't be Nix-built.

## T022 — Wire iOS E2E into flake.nix checks
- iOS E2E check uses `pkgs.lib.optionalAttrs isDarwin` (same pattern as android-e2e uses `!isDarwin`). No `requiredSystemFeatures` needed — iOS Simulator doesn't require special hardware features like KVM.
- The check only needs `bash`, `jq`, and `mcp-ios` in `nativeBuildInputs` — `xcrun`/`simctl` come from the macOS system and are available in the Nix build sandbox on darwin.

## T023 — .github/workflows/ci.yml
- GitHub Actions KVM access on ubuntu-latest requires a udev rule (`KERNEL=="kvm"` with MODE 0666) + udevadm reload/trigger — just `sudo chmod` on `/dev/kvm` is not persistent across steps.
- `browser-e2e-all.sh` produces `test-logs/browser-{firefox,webkit}/summary.json` (hyphenated prefix), while `browser-e2e.sh` produces `test-logs/browser/summary.json` — verify paths match when writing non-vacuous checks.

## T024 — Gitleaks pre-commit hook
- Used `.githooks/pre-commit` + `git config core.hooksPath .githooks` (via shellHook) instead of the Python `pre-commit` framework — simpler, no extra dependency.
- `AKIAIOSFODNN7EXAMPLE` is in gitleaks' built-in allowlist (AWS documentation example key). Use a non-example key like `wJalrXUtnFEMI/K7MDENG/bPxRfiCYSECRETKEY1` when testing detection.

## phase8-ci-pipeline-fix1 — CI shellcheck severity
- `shellcheck` exits non-zero on info-level SC1091 (`source "$VAR/file"` not followed). CI must use `--severity=warning` to avoid false failures on runtime-variable source paths.
