# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

## T005 — android/default.nix
- `fastmcp` and `mcp` are in nixpkgs-unstable (as of early 2026). `uiautomator2` and `adbutils` are NOT — must be built inline.
- `uiautomator2` uses `poetry-dynamic-versioning` as build backend; patch pyproject.toml to use plain `poetry-core` since version is already set in the sdist.
- `adbutils` uses `pbr` for builds; set `PBR_VERSION = version;` to avoid git-based version detection in the Nix sandbox.

## T006 — android/check.sh
- `wrapProgram` renames the original binary to `.android-mcp-wrapped` and creates a new wrapper script. To add a `--check` shim, rename the wrapProgram output to `.android-mcp-launch` and create a new outer wrapper.
- The outer wrapper must re-set PATH (e.g., `android-tools/bin`) since exec-ing check.sh bypasses the wrapProgram environment setup.

## T007 — Wire android into flake.nix
- T005 already wired mcp-android into flake.nix (packages, overlays, default symlinkJoin, smoke test nativeBuildInputs). Wiring tasks may be redundant when the package-creation task needs flake integration to verify its own done-when criteria.

## phase2-android-package-p-fix1 — Fix phase validation
- `fetchPypi` uses the old `/packages/source/` URL scheme which 404s for some PyPI packages (e.g., `android-mcp`). Use `fetchurl` with the direct hashed PyPI URL instead.
- `pyproject = false` in recent nixpkgs-unstable may not correctly select setuptools build hooks; use `format = "setuptools"` explicitly for pbr/setuptools packages.
- Scripts created in `postFixup` (after Nix's automatic shebang patching and after `wrapProgram`) must use Nix store bash paths (`${pkgs.bash}/bin/bash`) instead of `#!/usr/bin/env bash` — the Nix build sandbox lacks `/usr/bin/env`. `patchShebangs` in postFixup does NOT work on these files.

## T009 — browser/check.sh
- The `buildNpmPackage` `postInstall` hook is the equivalent of `postFixup` for python packages — it runs after `makeWrapper`, so the same rename-and-shim pattern applies. Use `postInstall` (not `postFixup`) since `buildNpmPackage` doesn't have a meaningful fixup phase.
- Chromium binary layout under `playwright-driver.browsers` may vary: check both `chrome-linux64/chrome` and `chrome-linux/chrome` for compatibility across playwright versions.

## T008 — browser/default.nix
- `@playwright/mcp` 0.0.56 is the latest stable version aligned with nixpkgs playwright-driver 1.58.2 (uses playwright 1.58.0-alpha-2026-01-16). Version 0.0.57+ moved to playwright 1.59.x.
- `buildNpmPackage` with a local `package.json`/`package-lock.json` wrapper is the cleanest way to package an npm CLI tool. Set `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"` to prevent playwright from trying to download browsers during `npm install`.
- Chromium binary lives at `${playwright-driver.browsers}/chromium-<rev>/chrome-linux64/chrome`. The `makeWrapper --set PLAYWRIGHT_BROWSERS_PATH` approach makes it automatically discoverable by playwright.
