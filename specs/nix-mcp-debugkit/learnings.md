# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

- `fetchPypi` uses the old `/packages/source/` URL scheme which 404s for some PyPI packages (e.g., `android-mcp`). Use `fetchurl` with the direct hashed PyPI URL instead.
- `pyproject = false` in recent nixpkgs-unstable may not correctly select setuptools build hooks; use `format = "setuptools"` explicitly for pbr/setuptools packages.
- Scripts created in `postFixup` (after Nix's automatic shebang patching and after `wrapProgram`) must use Nix store bash paths (`${pkgs.bash}/bin/bash`) instead of `#!/usr/bin/env bash` — the Nix build sandbox lacks `/usr/bin/env`. `patchShebangs` in postFixup does NOT work on these files.

## phase2-android-package-p-fix1 — Fix phase validation
## T011 — ios/default.nix
- `ios-simulator-mcp` 1.5.2 entry point is `build/index.js` (not `cli.js` like playwright). The bin field maps `ios-simulator-mcp` to `build/index.js`.
- Inside `meta = with pkgs.lib; { ... }`, use `platforms.darwin` (not `lib.platforms.darwin`) since `with` already brings `lib` attrs into scope.
- Wiring into flake.nix (replacing placeholder) is needed in the package task itself to satisfy done-when criteria — consistent with T008/T010 pattern.

## T013 — Wire iOS into flake.nix (darwin-only)
- T011 wired mcp-ios unconditionally; T013's real work is making it darwin-conditional using `lib.optionalAttrs isDarwin` for packages/overlays and `lib.optionals isDarwin` for list inputs (smoke test nativeBuildInputs).
- In overlays (outside `eachDefaultSystem`), use `prev.lib` and `prev.stdenv.isDarwin` since `pkgs` isn't in scope — `prev` is the nixpkgs being overlaid.

## phase4-ios-package-p-fix1 — Smoke test platform skip
- T013 made mcp-ios darwin-only in flake.nix but the smoke test's "binary exists" loop used `test_fail` for missing binaries. The `--check` and `--help` loops already handled missing binaries with `test_skip`, but the first loop needed an explicit platform check to skip mcp-ios on non-darwin instead of failing.

## T014 — test-apps/android/ minimal Java counter app
- Building an Android APK in Nix without Gradle: use `composeAndroidPackages` for SDK, then drive `aapt2 compile` → `aapt2 link` → `javac` → `d8` → `zip` → `zipalign` → `apksigner` manually in `buildPhase`. The `buildApp` function in androidenv is Ant-based and outdated.
- `composeAndroidPackages` requires `config.android_sdk.accept_license = true` in the nixpkgs import config (or env `NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1`). Without this, the SDK derivation fails evaluation.
- The old `test-app-android` placeholder was a `writeShellScriptBin` with a `/bin/` output; the real APK derivation outputs to `$out/test-app-android.apk` — smoke test `TEST_APP_PATHS` only checks substring match, so path format change is safe.
