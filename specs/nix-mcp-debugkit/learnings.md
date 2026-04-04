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

## T030 — E2E checks removed from flake.nix

- E2E test checks (android-e2e, browser-e2e, ios-e2e) were removed from `checks.*` in flake.nix. The Nix build sandbox cannot provide KVM (android emulator), real browser processes, or macOS simulators. These tests run only in CI workflow steps (`.github/workflows/ci.yml`) where the runners have the required hardware/capabilities. `nix flake check` now runs smoke tests only.

## T030 — Dependabot security_update_not_possible

- `ios-simulator-mcp@1.5.2` (latest as of 2026-04) hard-pins `@modelcontextprotocol/sdk` at `1.18.2`. The lowest non-vulnerable SDK version is `1.26.0`, so Dependabot cannot resolve the conflict and exits 1 (`security_update_not_possible`).
- Fix: create `.github/dependabot.yml` with an `ignore` rule for `@modelcontextprotocol/sdk` in the `/ios` directory. Remove the ignore once upstream `ios-simulator-mcp` supports SDK >= 1.26.0.

## T030 — CI workflow fixes (attempt 2)

- `cachix/install-nix-action@v27` fails on macOS runners with `DS Error: -14135 (eDSRecordAlreadyExists)` when `nixbld` users already exist. Upgrade to `@v30` which handles this.
- `aquasecurity/trivy-action` uses `v`-prefixed tags (e.g., `@v0.28.0` not `@0.28.0`).
- Fallback SARIF JSON `{"runs":[{"results":[]}]}` is invalid — must include `$schema`, `version`, and `runs[].tool.driver` fields for `github/codeql-action/upload-sarif` to accept it.
- Chromium in the Nix build sandbox fails with "sandboxing failed" because user namespaces aren't available. Pass `--no-sandbox` in check scripts and set `PLAYWRIGHT_CHROMIUM_SANDBOX=0` env in CI.
- Security scanner jobs (Snyk, SonarCloud) should use `if: env.TOKEN != ''` guards and `continue-on-error: true` to gracefully skip when secrets aren't configured.
- E2E CI jobs must build test prerequisites and export env vars before running test scripts. The devshell does NOT include MCP binaries or test apps. Each E2E job needs: (1) `nix build` the required packages, (2) export `TEST_APK_PATH`/`TEST_WEB_DIR` env vars, (3) prepend MCP binary paths to `$PATH`. These exports carry into `nix develop --command` since it inherits the parent shell environment.
