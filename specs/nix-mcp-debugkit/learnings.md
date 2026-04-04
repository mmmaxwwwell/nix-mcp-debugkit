# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

- `fetchPypi` uses the old `/packages/source/` URL scheme which 404s for some PyPI packages (e.g., `android-mcp`). Use `fetchurl` with the direct hashed PyPI URL instead.
- `pyproject = false` in recent nixpkgs-unstable may not correctly select setuptools build hooks; use `format = "setuptools"` explicitly for pbr/setuptools packages.
- Scripts created in `postFixup` (after Nix's automatic shebang patching and after `wrapProgram`) must use Nix store bash paths (`${pkgs.bash}/bin/bash`) instead of `#!/usr/bin/env bash` — the Nix build sandbox lacks `/usr/bin/env`. `patchShebangs` in postFixup does NOT work on these files.

## phase2-android-package-p-fix1 — Fix phase validation
## phase4-ios-package-p-fix1 — Smoke test platform skip
- T013 made mcp-ios darwin-only in flake.nix but the smoke test's "binary exists" loop used `test_fail` for missing binaries. The `--check` and `--help` loops already handled missing binaries with `test_skip`, but the first loop needed an explicit platform check to skip mcp-ios on non-darwin instead of failing.

## T014 — test-apps/android/ minimal Java counter app
- Building an Android APK in Nix without Gradle: use `composeAndroidPackages` for SDK, then drive `aapt2 compile` → `aapt2 link` → `javac` → `d8` → `zip` → `zipalign` → `apksigner` manually in `buildPhase`. The `buildApp` function in androidenv is Ant-based and outdated.
- `composeAndroidPackages` requires `config.android_sdk.accept_license = true` in the nixpkgs import config (or env `NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1`). Without this, the SDK derivation fails evaluation.
- The old `test-app-android` placeholder was a `writeShellScriptBin` with a `/bin/` output; the real APK derivation outputs to `$out/test-app-android.apk` — smoke test `TEST_APP_PATHS` only checks substring match, so path format change is safe.

## T015 — tests/android-e2e.sh
- android-mcp (PyPI) uses FastMCP and uiautomator2. The MCP tool names may vary; the E2E script tries multiple tool name variants (click/tap, dump_hierarchy/get_screen_info, type/set_text) with fallbacks.
- AVD creation can be done via manual INI files when `avdmanager` is not on PATH (common in Nix where only the emulator + system image are provided). The key fields are `image.sysdir.1` pointing at the system image and `hw.cpu.arch=x86_64`.

## T016 — Wire android E2E into flake.nix checks
- Use `requiredSystemFeatures = [ "kvm" ]` on the check derivation so Nix only runs it on builders with KVM support. Combined with `lib.optionalAttrs (!isDarwin)` to restrict to Linux.
- The emulator SDK needs a separate `composeAndroidPackages` call with `includeEmulator = true`, `includeSystemImages = true`, `systemImageTypes = [ "default" ]`, and `abiVersions = [ "x86_64" ]` — the test-app-android composition omits these to keep build times minimal.

## phase5-android-test-app-e2e-fix1 — Unfree license fix
- `config.android_sdk.accept_license = true` is NOT sufficient for Nix flake/pure evaluation — it only controls the Android SDK's internal license check. You also need `config.allowUnfree = true` (or a targeted `allowUnfreePredicate`) in the nixpkgs import config to prevent Nix from refusing to evaluate the `androidsdk` derivation.

## T018 — tests/browser-e2e.sh (Chromium E2E)
- @playwright/mcp v0.0.56 tool names: `browser_navigate`, `browser_take_screenshot`, `browser_click`, `browser_type`, `browser_fill_form`, `browser_snapshot`, `browser_evaluate`. Use `--browser chromium` CLI flag to select engine.
- `mcp_start` in common.sh was updated to forward extra args (`"$@"`) so browser-e2e.sh can pass `--browser $BROWSER`. Backward-compatible — existing callers with one arg still work.
- `browser_snapshot` returns an accessibility tree with `[ref=<id>]` markers; parse refs with `grep -oP 'ref=\K[^\]]+'` and pass them to click/type tools for reliable element targeting.

## T019 — tests/browser-e2e-all.sh (Firefox + WebKit)
- browser-e2e.sh already supports `BROWSER_TYPE` env var, so browser-e2e-all.sh simply delegates to it in a loop — no need to duplicate test logic.
- Each browser invocation needs a unique `BROWSER_E2E_PORT` to avoid port conflicts when run sequentially (and to be safe if parallelized later).
