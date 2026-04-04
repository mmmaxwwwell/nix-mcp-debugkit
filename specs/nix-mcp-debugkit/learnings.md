# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

- `fetchPypi` uses the old `/packages/source/` URL scheme which 404s for some PyPI packages (e.g., `android-mcp`). Use `fetchurl` with the direct hashed PyPI URL instead.
- `pyproject = false` in recent nixpkgs-unstable may not correctly select setuptools build hooks; use `format = "setuptools"` explicitly for pbr/setuptools packages.
- Scripts created in `postFixup` (after Nix's automatic shebang patching and after `wrapProgram`) must use Nix store bash paths (`${pkgs.bash}/bin/bash`) instead of `#!/usr/bin/env bash` — the Nix build sandbox lacks `/usr/bin/env`. `patchShebangs` in postFixup does NOT work on these files.

## phase2-android-package-p-fix1 — Fix phase validation
- T013 made mcp-ios darwin-only in flake.nix but the smoke test's "binary exists" loop used `test_fail` for missing binaries. The `--check` and `--help` loops already handled missing binaries with `test_skip`, but the first loop needed an explicit platform check to skip mcp-ios on non-darwin instead of failing.

## phase4-ios-package-p-fix1 — Smoke test platform skip
## phase5-android-test-app-e2e-fix1 — Unfree license fix
- `config.android_sdk.accept_license = true` is NOT sufficient for Nix flake/pure evaluation — it only controls the Android SDK's internal license check. You also need `config.allowUnfree = true` (or a targeted `allowUnfreePredicate`) in the nixpkgs import config to prevent Nix from refusing to evaluate the `androidsdk` derivation.

## T018 — tests/browser-e2e.sh (Chromium E2E)
- @playwright/mcp v0.0.56 tool names: `browser_navigate`, `browser_take_screenshot`, `browser_click`, `browser_type`, `browser_fill_form`, `browser_snapshot`, `browser_evaluate`. Use `--browser chromium` CLI flag to select engine.
- `mcp_start` in common.sh was updated to forward extra args (`"$@"`) so browser-e2e.sh can pass `--browser $BROWSER`. Backward-compatible — existing callers with one arg still work.
- `browser_snapshot` returns an accessibility tree with `[ref=<id>]` markers; parse refs with `grep -oP 'ref=\K[^\]]+'` and pass them to click/type tools for reliable element targeting.

## T019 — tests/browser-e2e-all.sh (Firefox + WebKit)
- browser-e2e.sh already supports `BROWSER_TYPE` env var, so browser-e2e-all.sh simply delegates to it in a loop — no need to duplicate test logic.
- Each browser invocation needs a unique `BROWSER_E2E_PORT` to avoid port conflicts when run sequentially (and to be safe if parallelized later).

## T020 — Wire browser E2E into flake.nix checks
- Browser E2E check doesn't need `requiredSystemFeatures = [ "kvm" ]` (unlike android-e2e) — Playwright/Chromium runs in headless mode without hardware acceleration requirements.
- `PLAYWRIGHT_BROWSERS_PATH` is already baked into the mcp-browser wrapper via `makeWrapper`, so the check derivation doesn't need to set it explicitly.

## T021 — tests/ios-e2e.sh (iOS Simulator E2E)
- `ios-simulator-mcp` (v1.5.2) is the upstream package. Tool names are discovered at runtime via `tools/list` since they may vary across versions — the script probes for common names like `screenshot`, `take_screenshot`, `tap`, `click`.
- `xcrun simctl list devices available -j` gives JSON output; use `jq` to pick an iPhone simulator by name pattern and state, avoiding fragile text parsing.
- Stock iOS apps (e.g. `com.apple.Preferences`) serve as test targets since custom iOS apps can't be Nix-built.

## T022 — Wire iOS E2E into flake.nix checks
- iOS E2E check uses `pkgs.lib.optionalAttrs isDarwin` (same pattern as android-e2e uses `!isDarwin`). No `requiredSystemFeatures` needed — iOS Simulator doesn't require special hardware features like KVM.
- The check only needs `bash`, `jq`, and `mcp-ios` in `nativeBuildInputs` — `xcrun`/`simctl` come from the macOS system and are available in the Nix build sandbox on darwin.
