# Tasks — nix-mcp-debugkit

**Approach**: TDD with fix-validate loop per phase. Full CI/CD with Tier 1 + Snyk + SonarCloud security scanning. Enterprise-grade test infrastructure with real emulators, real browsers, real simulators. Shell-based E2E test orchestrators with structured JSON output. No auth, no network hardening — local Nix packaging tool. See Non-Goals for intentional omissions.

---

## Phase 1: Flake Scaffold + Test Infrastructure

- [x] T001 [P] Create flake.nix skeleton with all outputs [FR-001 through FR-009]
  Create `flake.nix` with inputs (nixpkgs-unstable, flake-utils), eachDefaultSystem iteration, placeholder packages, devShells.default (statix, deadnix, shellcheck, gitleaks, trivy, semgrep, jq, python3, nodejs, android-tools), overlays.default, and packages.${system}.default (symlinkJoin). Add `.envrc` with `use flake`. Verify `nix develop` enters shell with all tools.
  Done when: `nix develop` enters shell; `statix --version`, `shellcheck --version`, `jq --version`, `adb --version` all succeed inside shell; `nix flake show` lists all expected output categories

- [x] T002 [P] Create tests/common.sh with shared test utilities [FR-046, FR-047] [produces: IC-002]
  Implement: `start_test_run <target>`, `test_pass <name>`, `test_fail <name> <details>`, `test_skip <name> <reason>`, `finish_test_run` (writes summary.json), `mcp_start <binary>`, `mcp_stop`, `mcp_call <method> <params_json>` (sends JSON-RPC over stdin, reads response), `assert_json <json> <jq_expr> <expected>`, `assert_eq <actual> <expected> <msg>`, `assert_contains <haystack> <needle> <msg>`, `wait_for <name> <cmd> <timeout>`. All functions write structured output to `test-logs/<target>/`. Non-vacuous check: `finish_test_run` exits 1 if pass + fail == 0.
  Done when: `shellcheck tests/common.sh` passes; sourcing common.sh and running a mock test produces valid `test-logs/test/summary.json` with correct pass/fail/skip counts; `mcp_call` sends valid JSON-RPC and reads response

- [x] T003 Create tests/smoke.sh framework [SC-001 through SC-005, SC-014, SC-020] [consumes: IC-002]
  Smoke test script that sources common.sh. Tests: each package binary exists and is executable, `--check` flag is accepted (exits without crash), `--help` or MCP initialize handshake works, default package contains correct packages per platform, test app packages build. Wire into `checks.${system}.smoke` in flake.nix (as a Nix check derivation that runs smoke.sh).
  Done when: `nix flake check` runs smoke tests (they'll fail until packages exist — that's expected); `shellcheck tests/smoke.sh` passes; smoke.sh sources common.sh and writes structured output

- [x] T004 Create LICENSE file (MIT)
  Standard MIT license with copyright holder `mmmaxwwwell`.
  Done when: LICENSE file exists with MIT text

---

## Phase 2: Android Package [P]

- [x] T005 Create android/default.nix — mcp-android package [FR-010 through FR-014] [produces: IC-006]
  Use `buildPythonApplication` to package `android-mcp` from PyPI at exact pinned version. Determine current version from PyPI. Use `makeWrapper` to prepend `android-tools/bin` (adb) to PATH. Entry point: the upstream `android-mcp` console script. All CLI args pass through. Add `meta.description` and `meta.license`.
  Done when: `nix build .#mcp-android` succeeds; `result/bin/mcp-android` exists; `ldd` or `file` confirms it's a wrapper script; `strings result/bin/mcp-android | grep adb` confirms adb path wiring

- [x] T006 Create android/check.sh — pre-flight diagnostics [FR-015] [produces: IC-003]
  Shell script implementing `--check` for android: (1) verify `adb` binary on PATH and executable → ✓/✗, (2) run `adb devices` and check for at least one non-header line → ✓ with device list / ✗ with remediation "Start an emulator: emulator -avd <name> -no-window". Exit 0 if all pass, exit 1 if any fail. Wire into the mcp-android wrapper: if `$1 == "--check"`, exec check.sh instead of upstream.
  Done when: `mcp-android --check` runs without crashing (will show ✗ for device without emulator); output matches IC-003 format; `shellcheck android/check.sh` passes

- [~] T007 Wire android package into flake.nix [FR-001, FR-004, FR-005] — already completed by T005 (flake.nix already has mcp-android in packages, overlays, default symlinkJoin, and smoke tests)
  Add `packages.${system}.mcp-android` to flake outputs for Linux + darwin. Add to overlays.default. Add to default package symlinkJoin. Update smoke tests to verify android package.
  Done when: `nix flake show` lists mcp-android; `nix build .#mcp-android` succeeds; smoke test for android passes

- [x] phase2-android-package-p-fix1 Fix phase validation failure: read specs/nix-mcp-debugkit/validate/phase2-android-package-p/ for failure history

---

## Phase 3: Browser Package [P]

- [x] T008 Create browser/default.nix — mcp-browser package [FR-030 through FR-035] [produces: IC-006]
  Use `buildNpmPackage` to package `@playwright/mcp` at exact version aligned with nixpkgs `playwright-driver`. Check nixpkgs' playwright-driver version first: `nix eval nixpkgs#playwright-driver.version`. Pin @playwright/mcp to matching version. Use `makeWrapper` to set `PLAYWRIGHT_BROWSERS_PATH` to `${pkgs.playwright-driver.browsers}`. Entry point: upstream node CLI. All CLI args pass through.
  Done when: `nix build .#mcp-browser` succeeds; `result/bin/mcp-browser` exists; wrapper sets PLAYWRIGHT_BROWSERS_PATH; Chromium binary is reachable at the configured path

- [x] T009 Create browser/check.sh — pre-flight diagnostics [FR-036] [produces: IC-003]
  Shell script: (1) verify PLAYWRIGHT_BROWSERS_PATH is set and directory exists → ✓/✗, (2) find Chromium binary and attempt headless launch (`chromium --headless --disable-gpu --dump-dom about:blank`) → ✓ with version / ✗ with error details. Exit code per IC-003.
  Done when: `mcp-browser --check` reports Chromium version; output matches IC-003 format; `shellcheck browser/check.sh` passes

- [~] T010 Wire browser package into flake.nix [FR-002, FR-004, FR-005] — already completed by T008 (flake.nix already has mcp-browser in packages, overlays, default symlinkJoin, and smoke tests)
  Add `packages.${system}.mcp-browser` to flake outputs for all systems. Add to overlays.default. Add to default package. Update smoke tests.
  Done when: `nix flake show` lists mcp-browser; `nix build .#mcp-browser` succeeds; smoke test for browser passes

---

## Phase 4: iOS Package [P]

- [x] T011 Create ios/default.nix — mcp-ios package [FR-020 through FR-024] [produces: IC-006]
  Use `buildNpmPackage` for `ios-simulator-mcp` at exact pinned version (≥1.5.2). Set `meta.platforms = lib.platforms.darwin`. Use `makeWrapper` for PATH. Entry point: upstream node CLI. All CLI args pass through.
  Done when: `nix build .#mcp-ios` succeeds on macOS (or `nix eval` confirms derivation is valid); `nix eval .#packages.x86_64-linux.mcp-ios` fails with platform error on Linux

- [x] T012 Create ios/check.sh — pre-flight diagnostics [FR-025] [produces: IC-003]
  Shell script: (1) verify `xcrun simctl list` succeeds → ✓/✗ "Xcode CLI tools not found → install with xcode-select --install", (2) check for at least one simulator → ✓ with list / ✗ "No simulators found → create with xcrun simctl create". Exit code per IC-003.
  Done when: check.sh script exists; `shellcheck ios/check.sh` passes; output matches IC-003 format

- [x] T013 Wire iOS package into flake.nix [FR-003, FR-004, FR-005]
  Add `packages.${system}.mcp-ios` to flake outputs (darwin only — conditional in eachDefaultSystem). Add to overlays.default (darwin only). Add to default package (darwin only). Update smoke tests (skip iOS smoke on non-darwin).
  Done when: `nix flake show` lists mcp-ios on darwin; default package on Linux does NOT include mcp-ios

- [x] phase4-ios-package-p-fix1 Fix phase validation failure: read specs/nix-mcp-debugkit/validate/phase4-ios-package-p/ for failure history

---

## Phase 5: Android Test App + E2E

- [x] T014 Create test-apps/android/ — minimal Java counter app [FR-040, FR-048] [produces: IC-004]
  Create minimal Android app with: AndroidManifest.xml (package: com.nixmcpdebugkit.testapp, minSdk 28, targetSdk 34), single MainActivity.java with: Button (id: btn_tap, text: "Tap Me"), TextView (id: txt_counter, text: "Count: 0"), EditText (id: input_text, hint: "Type here"), ListView (id: list_items, 50 items "Item 1" through "Item 50"). Button click increments counter. Build with nixpkgs androidenv (androidenv.composeAndroidPackages for SDK, standard Java build). Package as `packages.${system}.test-app-android`.
  Done when: `nix build .#test-app-android` produces APK; APK installs on an emulator; app launches showing button, counter "Count: 0", text input, scrollable list

- [x] T015 Create tests/android-e2e.sh [FR-042, SC-008] [consumes: IC-001, IC-002, IC-004]
  E2E orchestrator that: (1) creates/boots headless Android emulator via androidenv.emulateApp or directly via emulator command (x86_64, API 34, -no-window -gpu swiftshader_indirect), (2) waits for boot (`adb shell getprop sys.boot_completed` == 1, 120s timeout), (3) waits for package manager ready (pm list packages count > 50, 300s), (4) installs test APK via `adb install`, (5) launches app via `adb shell am start -n com.nixmcpdebugkit.testapp/.MainActivity`, (6) starts mcp-android server, (7) exercises MCP tools: screenshot (verify base64 PNG), click btn_tap (verify counter becomes "Count: 1" via state read), type "hello" in input_text (verify text via state read), swipe list_items (verify scroll position changes), read accessibility tree (verify expected element IDs), (8) writes structured results per IC-002, (9) cleanup: kill emulator + MCP server on EXIT trap.
  Done when: android-e2e.sh passes with KVM; `test-logs/android/summary.json` shows pass > 0, fail == 0; all 5 MCP tool categories tested

- [ ] T016 Wire android E2E into flake.nix checks [FR-007]
  Add `checks.${system}.android-e2e` that runs android-e2e.sh. Only enable on Linux (requires KVM). The check derivation must have access to android-tools, the emulator, and the test APK.
  Done when: `nix flake check` includes android-e2e on Linux; check passes on KVM-enabled system

---

## Phase 6: Browser Test App + E2E

- [ ] T017 Create test-apps/web/ — static counter page [FR-041, FR-048] [produces: IC-005]
  Create `index.html`: button (id: btn-tap, text: "Tap Me"), span (id: counter, text: "Count: 0"), input (id: input-text, placeholder: "Type here"), link (id: link-page2, href: page2.html, text: "Go to Page 2"). Inline JS: button.onclick increments counter. Create `page2.html`: h1 (id: heading, text: "Page 2"), link back to index.html. Create `default.nix`: simple `runCommand` or `stdenv.mkDerivation` that copies files to $out. Package as `packages.${system}.test-app-web`.
  Done when: `nix build .#test-app-web` produces directory with index.html and page2.html; opening index.html in browser shows working counter

- [ ] T018 Create tests/browser-e2e.sh — Chromium E2E [FR-043, SC-009] [consumes: IC-001, IC-002, IC-005]
  E2E orchestrator: (1) serve test-app-web via `python3 -m http.server <port>` in background, (2) wait for server ready (curl localhost:<port>, 15s), (3) start mcp-browser server, (4) exercise MCP tools: navigate to http://localhost:<port>/index.html, screenshot (verify base64 PNG response), click btn-tap (verify counter changes to "Count: 1" via page content read), fill input-text with "hello world" (verify value), navigate via link-page2 (verify page2 heading "Page 2" visible), (5) write structured results, (6) cleanup on EXIT.
  Done when: browser-e2e.sh passes with Chromium; `test-logs/browser-chromium/summary.json` shows pass > 0, fail == 0; all tool categories tested

- [ ] T019 Create tests/browser-e2e-all.sh — Firefox + WebKit [FR-044, SC-010]
  CI-only script: (1) install Firefox and WebKit via `npx playwright install firefox webkit` (non-Nix, allowed in CI), (2) run same test logic as browser-e2e.sh but targeting each browser engine — check upstream @playwright/mcp CLI docs for exact flag syntax (may be `--browser firefox` or env var), (3) write separate structured results per browser to `test-logs/browser-firefox/` and `test-logs/browser-webkit/`.
  Done when: script passes when Firefox/WebKit are available; produces structured output for each browser; `shellcheck tests/browser-e2e-all.sh` passes

- [ ] T020 Wire browser E2E into flake.nix checks [FR-007]
  Add `checks.${system}.browser-e2e` that runs browser-e2e.sh (Chromium only — Nix-packaged).
  Done when: `nix flake check` includes browser-e2e; check passes

---

## Phase 7: iOS E2E

- [ ] T021 Create tests/ios-e2e.sh [FR-045, SC-011] [consumes: IC-001, IC-002]
  macOS-only E2E orchestrator: (1) list available simulators via `xcrun simctl list devices available`, pick an iPhone simulator, (2) boot simulator (`xcrun simctl boot <device-id>`), (3) wait for booted state (60s), (4) start mcp-ios server, (5) exercise MCP tools: screenshot (verify base64 PNG), tap center of screen (verify response), (6) write structured results, (7) cleanup: shutdown simulator on EXIT. Uses stock iOS apps (Settings, etc.) as test target since custom iOS apps can't be Nix-built.
  Done when: ios-e2e.sh passes on macOS with Xcode; `test-logs/ios/summary.json` shows pass > 0, fail == 0; screenshot and tap tools verified

- [ ] T022 Wire iOS E2E into flake.nix checks [FR-007]
  Add `checks.${system}.ios-e2e` (darwin only).
  Done when: `nix flake check` includes ios-e2e on darwin

---

## Phase 8: CI Pipeline

- [ ] T023 Create .github/workflows/ci.yml — full pipeline [FR-050 through FR-055, FR-058, FR-059]
  GitHub Actions workflow triggered on push and PR to main. Jobs:
  - **lint**: install Nix, `nix develop --command statix check .`, `nix develop --command deadnix .`, `nix develop --command shellcheck tests/*.sh`
  - **build-linux** (ubuntu-latest): `nix build .#mcp-android`, `nix build .#mcp-browser`, `nix build .#test-app-android`, `nix build .#test-app-web`
  - **build-macos** (macos-latest): `nix build .#mcp-ios`
  - **smoke-test** (ubuntu-latest): `nix flake check` — runs smoke tests
  - **e2e-android** (ubuntu-latest): enable KVM (`/dev/kvm` group), run `tests/android-e2e.sh`, upload test-logs/ as artifact, non-vacuous check on summary.json
  - **e2e-browser** (ubuntu-latest): run `tests/browser-e2e.sh` (Chromium), then `tests/browser-e2e-all.sh` (Firefox + WebKit), upload test-logs/, non-vacuous check per browser
  - **e2e-ios** (macos-latest): run `tests/ios-e2e.sh`, upload test-logs/, non-vacuous check
  All test jobs upload `test-logs/` as artifacts on failure. All test jobs assert summary.json has pass > 0.
  Done when: ci.yml passes YAML lint; all job definitions reference correct scripts and artifacts; non-vacuous verification steps present in every test job

- [ ] T024 Add Gitleaks pre-commit hook [FR-060]
  Add `.pre-commit-config.yaml` with gitleaks hook OR a git hooks script at `.githooks/pre-commit`. Include `pre-commit` in devShell. Document setup in README.
  Done when: committing a file with a fake secret (e.g., `AWS_SECRET_ACCESS_KEY=AKIA...`) is rejected; hook runs automatically after `nix develop`

---

## Phase 9: Security Scanning

- [ ] T025 Add security scan jobs to ci.yml [FR-056, FR-057, FR-058]
  Add jobs to ci.yml:
  - **security-gitleaks**: run gitleaks detect, output SARIF, upload via codeql-action/upload-sarif
  - **security-trivy**: run trivy fs scan, output SARIF, upload
  - **security-semgrep**: run semgrep with p/default config, output SARIF, upload
  - **security-snyk**: run snyk test (needs SNYK_TOKEN secret), output SARIF, upload. `snyk monitor` on main branch. Start with `continue-on-error: true`.
  - **security-sonarcloud**: run sonar-scanner (needs SONAR_TOKEN secret). Configure sonar-project.properties.
  All scanners write JSON to `test-logs/security/`. Non-vacuous check: every scanner output > 0 bytes. Quality gate: fail on critical/high (except Snyk initially).
  Done when: security jobs run in CI; SARIF appears in GitHub Security tab; no critical findings

- [ ] T026 Create local security scan script [reference: security.md]
  Create `scripts/security-scan.sh` that runs gitleaks, trivy, semgrep locally with JSON output to `test-logs/security/`. Summary at end. Include in devShell path.
  Done when: `security-scan.sh` runs locally and produces output; `shellcheck scripts/security-scan.sh` passes

---

## Phase 10: README + Documentation

- [ ] T027 Write README.md
  Human-facing README with: project overview, badges (CI status, license), quick start (`nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-browser`), flake input usage (individual, default, overlay), Claude Code MCP config JSON examples (all 3 targets), prerequisites per target (KVM, Xcode), `--check` usage for agents, troubleshooting (common errors, browser version mismatch, KVM missing), CI setup for contributors (SNYK_TOKEN, SONAR_TOKEN), contributing section, license.
  Done when: README renders correctly; all nix run commands are accurate; MCP config JSON is valid; prerequisites listed per target

- [ ] T028 Document CI secrets in README
  Add CI Setup section: how to get SNYK_TOKEN (snyk.io free signup), how to set up SonarCloud (free for public repos), where to add as GitHub secrets.
  Done when: README has CI Setup section with step-by-step instructions for both tokens

---

## Phase 11: Final Validation

- [ ] T029 Run full local validation
  Run `nix flake check` (smoke tests), run android-e2e.sh (if KVM available), run browser-e2e.sh, verify all test-logs/ have valid summary.json with pass > 0 and fail == 0. Run `statix check .`, `deadnix .`, `shellcheck tests/*.sh`.
  Done when: all tests pass locally; all lint passes; structured output valid

- [ ] T030 [needs: gh, ci-loop] Push and validate CI
  Push to GitHub. Monitor all CI jobs. Fix any failures. Verify: all jobs green, SARIF uploaded, test artifacts downloadable, non-vacuous checks pass.
  Done when: all CI jobs pass; GitHub Security tab shows scan results; no critical/high findings

- [ ] T031 [needs: gh] Observable output validation
  Verify README badges render. Verify CI artifacts are downloadable. Verify `nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-browser` works from a clean system. Run acceptance scenarios from spec.
  Done when: badges render correctly; remote nix run works; acceptance scenarios verified

- [ ] REVIEW Code review [all phases]
  Review all code for: Nix expression quality, shell script safety, test coverage completeness, documentation accuracy, security (no hardcoded secrets, no unsafe shell expansions). Write REVIEW-TODO.md with findings. Fix issues. Re-run fix-validate loop.
  Done when: no critical findings in review; all fixes applied; tests still pass
