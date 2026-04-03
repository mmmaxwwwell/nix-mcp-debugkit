# Research — nix-mcp-debugkit

## Decisions & Rationale

### Nix as the entire build system
**Decision**: All packages built with standard nixpkgs builders (buildPythonApplication, buildNpmPackage, androidenv). No Makefile, no custom build scripts beyond Nix.
**Rationale**: This is a Nix packaging project — the "application" IS the Nix expressions. Adding another build system layer would violate Constitution VI (Simplicity).
**Rejected**: Makefile wrapping nix commands — unnecessary indirection. The flake IS the build system.

### Python packaging for android-mcp
**Decision**: Use `buildPythonApplication` from nixpkgs to package the `android-mcp` PyPI package.
**Rationale**: Standard nixpkgs pattern for Python CLI tools. Handles dependencies, entry points, and PATH wiring via makeWrapper.
**Rejected**: `uv2nix` / `pyproject.nix` — adds complexity; `buildPythonApplication` is sufficient for a single package. `uvx` ephemeral execution — breaks Nix purity, downloads at runtime.

### npm packaging for browser and iOS servers
**Decision**: Use `buildNpmPackage` from nixpkgs for both `@playwright/mcp` and `ios-simulator-mcp`.
**Rationale**: Standard nixpkgs pattern for npm packages. Handles npm dependencies, lockfile pinning, and produces a runnable Node.js package.
**Rejected**: `dream2nix` — more complex, not needed for simple npm packages. `node2nix` — older approach, buildNpmPackage is preferred.

### Playwright browser version alignment strategy
**Decision**: Pin `@playwright/mcp` to the version that matches whatever `playwright-driver` nixpkgs ships. If nixpkgs has playwright-driver 1.42.x, use @playwright/mcp 1.42.x.
**Rationale**: The #1 source of Playwright-on-Nix breakage is version mismatch between the npm package and the browser binaries. Aligning to nixpkgs eliminates this. See nixpkgs#443704.
**Rejected**: Building custom browser derivations for arbitrary Playwright versions — fragile, high maintenance. Using Playwright's own download in the package — breaks Nix sandbox.
**Reference**: [benjaminkitt/nix-playwright-mcp](https://github.com/benjaminkitt/nix-playwright-mcp), [akirak/nix-playwright-mcp](https://github.com/akirak/nix-playwright-mcp), [NixOS Wiki: Playwright](https://nixos.wiki/wiki/Playwright)

### Firefox and WebKit not in Nix package, tested in CI
**Decision**: The mcp-browser Nix package ships Chromium only (from nixpkgs playwright-driver.browsers). Firefox and WebKit are tested in CI using Playwright's own browser installer.
**Rationale**: nixpkgs only packages Chromium for playwright-driver (see nixpkgs#288826). Packaging Firefox/WebKit ourselves is a massive, fragile undertaking. The pragmatic solution: ship what Nix can provide, test everything in CI.
**User preference**: "ship everything the upstream supports, first class support for everything" — this is honored in CI testing, not in the Nix package itself.

### Android emulator for E2E tests
**Decision**: Use nixpkgs `androidenv.emulateApp` to create a headless Android emulator with x86_64 system image, API 34.
**Rationale**: User was emphatic about real runtime testing. nixpkgs provides androidenv which can provision emulators declaratively. KVM is required but available on GitHub Actions Linux runners for public repos.
**Reference**: [NixOS Wiki: Android](https://wiki.nixos.org/wiki/Android), [nixpkgs androidenv](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/mobile/androidenv/emulate-app.nix), [kuhree/flake-emulators](https://github.com/kuhree/flake-emulators)
**Risk**: Android emulator in Nix has known issues (nixpkgs#267176). May need fallback to `android-nixpkgs` from tadfisher.

### Minimal Java test app (not Flutter)
**Decision**: Build a minimal Java Android app using nixpkgs androidenv, minSdkVersion 28, targetSdkVersion 34.
**Rationale**: Lightest possible build closure. The test app exists solely to verify MCP tool functionality — no framework needed.
**Rejected**: Flutter — enormous build closure, adds Flutter SDK dependency. Kotlin — adds kotlin compiler dependency for no benefit in a trivial app. Pre-built APK — breaks Nix purity.

### Android minSdkVersion 28 (Android 9)
**Decision**: Target API 28 as minimum.
**Rationale**: Covers 95%+ of non-EOL devices from reputable manufacturers. Android 9 is the oldest version still receiving security patches from major OEMs (Samsung, Google, etc.).
**Rejected**: API 21 (too old, drops useful APIs). API 33+ (too new, excludes many active devices).

### Test framework: shell-based orchestrators
**Decision**: E2E tests are bash scripts that boot runtimes, send MCP commands over stdio, and verify responses. No pytest, no vitest, no test framework.
**Rationale**: The system under test is a set of Nix-packaged executables that speak JSON-RPC over stdio. A shell script is the most natural way to test "start process, send stdin, check stdout." Adding a test framework would mean choosing a language runtime just for tests.
**Approach**: Each orchestrator (android-e2e.sh, browser-e2e.sh, ios-e2e.sh) sources common.sh for shared utilities (wait_for, assert_json, write_summary).

### Structured test output: custom JSON
**Decision**: Test orchestrators write `test-logs/<target>/summary.json` with `{pass, fail, skip, duration, failures[]}` format.
**Rationale**: Required by spec-kit for agent-readable test output. Shell scripts produce this directly — no custom reporter needed since there's no test framework.

### nixpkgs-unstable as upstream pin
**Decision**: Use `nixpkgs-unstable` flake input.
**Rationale**: Most up-to-date playwright-driver version. The @playwright/mcp npm pin must align with nixpkgs' playwright-driver, so using unstable gives us the newest compatible version.
**Rejected**: `nixos-24.11` / `nixos-25.05` — stable channels lag on playwright-driver versions, forcing us to use older @playwright/mcp.

### flake-utils for multi-platform
**Decision**: Use `flake-utils.lib.eachDefaultSystem` for platform iteration.
**Rationale**: Standard approach. Avoids hand-rolling system loops. Per Constitution requirement.

### --check pre-flight: wrapper-side addition
**Decision**: Each wrapper includes a `--check` flag implemented in a shell script (check.sh) that runs before delegating to upstream.
**Rationale**: Agents need structured diagnostics. Upstream servers don't provide pre-flight checks. This is the only wrapper-side logic — justified by agent UX needs.
**Constitution note**: Principle III (Minimal Wrapping) says "minimum necessary." Pre-flight checks are necessary for the agent use case — documented as intentional scope expansion.

### Security scanning: maximum free coverage
**Decision**: Gitleaks + Trivy + Semgrep + Snyk + SonarCloud.
**Rationale**: User said "if it's free to public projects use that shit." All five are free for public repos. Gitleaks catches secrets, Trivy catches dependency vulns, Semgrep catches code patterns, Snyk adds reachability analysis, SonarCloud adds code quality.

### CI: GitHub Actions with KVM Linux + macOS
**Decision**: Standard GitHub Actions runners. Linux with KVM for Android emulator E2E. macOS for iOS E2E.
**Rationale**: Public repo gets free runners including KVM-enabled Linux. macOS is 10x cost but user accepted ("whatever works for cicd"). No self-hosted runners needed.
**Reference**: [GitHub Actions: Hardware accelerated Android virtualization](https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/)

### Linting: statix + deadnix + shellcheck
**Decision**: statix for Nix linting, deadnix for unused Nix code detection, shellcheck for bash scripts.
**Rationale**: All in nixpkgs, zero-config, cover the two languages in this project (Nix, bash).
**Rejected**: nixfmt — formatting only, less useful than structural linting. nix-linter — less maintained than statix.

### iOS test target: stock app, not custom-built
**Decision**: iOS E2E tests interact with a stock iOS app (e.g., Settings or Contacts) rather than building a custom iOS test app.
**Rationale**: Building an iOS app requires Xcode's proprietary build system (xcodebuild), which can't run inside a Nix derivation. A stock app is sufficient to verify screenshot and tap MCP tools. If a custom app is needed later, it would be built via xcodebuild in the macOS CI step.
**Rejected**: Nix-built iOS app — impossible without Xcode toolchain. Pre-built IPA — would need to be committed as a binary blob.
