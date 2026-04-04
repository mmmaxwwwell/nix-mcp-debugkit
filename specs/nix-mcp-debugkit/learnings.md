# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

- `fetchPypi` uses the old `/packages/source/` URL scheme which 404s for some PyPI packages (e.g., `android-mcp`). Use `fetchurl` with the direct hashed PyPI URL instead.
- `pyproject = false` in recent nixpkgs-unstable may not correctly select setuptools build hooks; use `format = "setuptools"` explicitly for pbr/setuptools packages.
- Scripts created in `postFixup` (after Nix's automatic shebang patching and after `wrapProgram`) must use Nix store bash paths (`${pkgs.bash}/bin/bash`) instead of `#!/usr/bin/env bash` — the Nix build sandbox lacks `/usr/bin/env`. `patchShebangs` in postFixup does NOT work on these files.

- T013 made mcp-ios darwin-only in flake.nix but the smoke test's "binary exists" loop used `test_fail` for missing binaries. The `--check` and `--help` loops already handled missing binaries with `test_skip`, but the first loop needed an explicit platform check to skip mcp-ios on non-darwin instead of failing.

- `config.android_sdk.accept_license = true` is NOT sufficient for Nix flake/pure evaluation — it only controls the Android SDK's internal license check. You also need `config.allowUnfree = true` (or a targeted `allowUnfreePredicate`) in the nixpkgs import config to prevent Nix from refusing to evaluate the `androidsdk` derivation.

## phase2-android-package-p-fix1 — Fix phase validation
## phase4-ios-package-p-fix1 — Smoke test platform skip
## phase5-android-test-app-e2e-fix1 — Unfree license fix
- `shellcheck` exits non-zero on info-level SC1091 (`source "$VAR/file"` not followed). CI must use `--severity=warning` to avoid false failures on runtime-variable source paths.

## phase8-ci-pipeline-fix1 — CI shellcheck severity

## phase11-final-validation — T029

- `nix flake check` (with builds) requires the nix daemon socket (`NIX_REMOTE=daemon`) when the nix store is owned by `nobody`. Use `--no-build` for evaluation-only validation when sandbox builds aren't feasible (e.g., no KVM for android-e2e).
- browser-e2e.sh needs `mcp-browser` on PATH and `TEST_WEB_DIR` set — build both with `nix build .#mcp-browser` and `nix build .#test-app-web` first.
