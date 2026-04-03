# Feature Specification: nix-mcp-debugkit

**Created**: 2026-04-03
**Status**: Draft
**Preset**: local
**License**: MIT

## Overview

A Nix flake that wraps three upstream MCP (Model Context Protocol) servers — Android, iOS, and Browser — so they work out of the box on NixOS and Nix-enabled systems. Each wrapper packages an upstream MCP server with its native dependencies. The primary consumers are AI agents (Claude Code, Cursor, etc.) that use these MCP servers to take screenshots, tap UI elements, read accessibility trees, and interact with running apps.

The flake includes comprehensive E2E tests that spin up real emulators/browsers and exercise each MCP server against a minimal test application.

---

## User Scenarios & Testing

### User Story 1 — Agent uses browser MCP to debug a web app (Priority: P1)

An AI agent working on a web application adds `mcp-browser` to its MCP config. The agent launches a headless browser, navigates to the app, takes screenshots, clicks elements, fills forms, and reads the DOM — all through the MCP protocol over stdio. This replaces blind scripting where agents write CSS selectors without seeing the page.

**Why this priority**: Browser debugging is the most common use case — every web project benefits. Works on all platforms (Linux + macOS). Has the widest audience.

**Independent Test**: Can be fully tested by launching the MCP server, connecting via stdio, and verifying it can navigate to a page and take a screenshot. Delivers value: agents can visually debug web apps.

**Acceptance Scenarios**:

1. **Given** a Nix-enabled Linux system, **When** the user runs `nix run .#mcp-browser`, **Then** the MCP server starts and accepts stdio connections
2. **Given** a running mcp-browser server, **When** an agent sends a "navigate" tool call to a URL, **Then** the server opens the page in headless Chromium and returns success
3. **Given** a running mcp-browser server with a page loaded, **When** an agent sends a "screenshot" tool call, **Then** the server returns a base64-encoded screenshot of the current page
4. **Given** a running mcp-browser server with a page loaded, **When** an agent sends a "click" tool call targeting a button element, **Then** the server clicks the button and the page state updates accordingly
5. **Given** a user's flake.nix, **When** they add `mcp-debugkit.packages.${system}.mcp-browser` to their devShell, **Then** `mcp-browser` is available on PATH inside `nix develop`
6. **Given** a running mcp-browser server, **When** an agent passes `--browser firefox` to the upstream server, **Then** the argument is forwarded and the server uses Firefox (if available via PLAYWRIGHT_BROWSERS_PATH)

---

### User Story 2 — Agent uses Android MCP to debug a mobile app (Priority: P1)

An AI agent working on an Android app adds `mcp-android` to its MCP config. With an emulator or physical device connected, the agent takes screenshots, taps buttons, types text, swipes, and reads the accessibility tree — all through MCP.

**Why this priority**: Android is a major platform. The MCP server enables agents to do visual QA on mobile apps, which is otherwise impossible without human intervention.

**Independent Test**: Can be tested by launching the MCP server with a running Android emulator, connecting via stdio, and verifying it can take a screenshot and read UI state.

**Acceptance Scenarios**:

1. **Given** a Nix-enabled Linux system with KVM, **When** the user runs `nix run .#mcp-android`, **Then** the MCP server starts and `adb` is on its PATH
2. **Given** a running mcp-android server and a connected emulator, **When** an agent sends a "screenshot" tool call, **Then** the server returns a screenshot of the emulator screen
3. **Given** a running mcp-android server, **When** an agent sends a "click" tool call with coordinates, **Then** the server taps the specified location via adb
4. **Given** a running mcp-android server, **When** an agent sends a "type" tool call with text, **Then** the server inputs the text on the focused element
5. **Given** a running mcp-android server, **When** an agent sends a state/accessibility tool call, **Then** the server returns the current UI hierarchy

---

### User Story 3 — Agent uses iOS MCP to debug an iOS app (Priority: P2)

An AI agent working on an iOS app adds `mcp-ios` to its MCP config on a macOS system with Xcode. The agent interacts with an iOS simulator — screenshots, taps, accessibility tree reads.

**Why this priority**: iOS-only (darwin), narrower audience than Android/browser. Still critical for iOS app development workflows.

**Independent Test**: Can be tested on macOS with Xcode by launching an iOS simulator, starting the MCP server, and verifying screenshot and tap tools work.

**Acceptance Scenarios**:

1. **Given** a macOS system with Xcode and Nix, **When** the user runs `nix run .#mcp-ios`, **Then** the MCP server starts and `xcrun simctl` is available
2. **Given** a running mcp-ios server and a booted iOS simulator, **When** an agent sends a "screenshot" tool call, **Then** the server returns a screenshot of the simulator
3. **Given** a running mcp-ios server, **When** an agent sends a "tap" tool call with coordinates, **Then** the server taps the specified location in the simulator
4. **Given** the user is on Linux, **When** they try to build `mcp-ios`, **Then** the build fails at Nix evaluation time with a clear platform error (not at build time)

---

### User Story 4 — Consumer imports the flake into their project (Priority: P1)

A developer adds `nix-mcp-debugkit` as a flake input to their project, picking individual MCP packages for their devShell or using the overlay to get all packages in their nixpkgs.

**Why this priority**: This is how every consumer accesses the tool. Ergonomic flake integration is essential.

**Independent Test**: Can be tested by creating a minimal flake.nix that imports nix-mcp-debugkit, entering the devShell, and verifying the MCP server binaries are on PATH.

**Acceptance Scenarios**:

1. **Given** a project flake.nix with `mcp-debugkit` as an input, **When** the user adds `mcp-debugkit.packages.${system}.mcp-android` to devShell packages, **Then** `mcp-android` is on PATH in `nix develop`
2. **Given** a project flake.nix using `mcp-debugkit.overlays.default`, **When** the user references `pkgs.mcp-android`, **Then** the package is available through the overlay
3. **Given** a project flake.nix, **When** the user adds `mcp-debugkit.packages.${system}.default`, **Then** all MCP packages for that system are available on PATH
4. **Given** a user on Linux, **When** they use the `default` package, **Then** it includes `mcp-android` and `mcp-browser` but NOT `mcp-ios`

---

### User Story 5 — Pre-flight check for agent diagnostics (Priority: P2)

An agent runs `mcp-android --check` before starting a debugging session. The check reports whether prerequisites are met (adb connected, emulator running, browser launchable) with structured, actionable error messages that the agent can parse and act on.

**Why this priority**: Agents are the primary consumers. When something fails, agents need clear diagnostic output to self-fix (start the emulator, connect a device) rather than parsing opaque Python/Node tracebacks.

**Independent Test**: Can be tested by running `--check` with and without prerequisites met and verifying the output format.

**Acceptance Scenarios**:

1. **Given** mcp-android is installed and an emulator is running, **When** an agent runs `mcp-android --check`, **Then** output shows all checks passing with checkmarks
2. **Given** mcp-android is installed but no device/emulator is connected, **When** an agent runs `mcp-android --check`, **Then** output shows the adb check failing with a specific remediation message ("Start an emulator: emulator -avd <name> -no-window")
3. **Given** mcp-browser is installed, **When** an agent runs `mcp-browser --check`, **Then** output verifies Chromium can launch headless and reports the browser version
4. **Given** mcp-ios on a Mac without Xcode, **When** an agent runs `mcp-ios --check`, **Then** output reports xcrun is missing and suggests installing Xcode CLI tools

---

### Edge Cases & Failure Modes

- **EC-001**: Android emulator not running — mcp-android should fail fast with a clear error, not hang waiting for a device
- **EC-002**: adb daemon not started — the wrapper should handle `adb start-server` or report the issue
- **EC-003**: Multiple Android devices connected — upstream behavior (device selection) passes through; --check should list all connected devices
- **EC-004**: Playwright browser version mismatch — if PLAYWRIGHT_BROWSERS_PATH points to wrong version, report the version mismatch clearly
- **EC-005**: Chromium fails to launch (missing GPU, display server) — headless mode should work without a display; report if it doesn't
- **EC-006**: iOS simulator not booted — mcp-ios should report which simulators are available and suggest booting one
- **EC-007**: Xcode not installed on macOS — mcp-ios --check should detect this and give install instructions
- **EC-008**: Nix sandbox prevents browser download — this is expected; the package ships browsers via nixpkgs, not Playwright download
- **EC-009**: Stale adb connection — device disconnected mid-session; upstream handles this, wrapper passes through errors
- **EC-010**: Concurrent MCP server instances — each instance should work independently (no port conflicts since stdio transport)

---

## Requirements

### Functional Requirements — Flake Structure

- **FR-001**: The flake MUST expose `packages.${system}.mcp-android` for `x86_64-linux` and `aarch64-linux` and `aarch64-darwin`
- **FR-002**: The flake MUST expose `packages.${system}.mcp-browser` for `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`
- **FR-003**: The flake MUST expose `packages.${system}.mcp-ios` for `aarch64-darwin` ONLY
- **FR-004**: The flake MUST expose `packages.${system}.default` that includes all packages available for that system
  Example: on `x86_64-linux`, default includes mcp-android + mcp-browser; on `aarch64-darwin`, default includes all three
- **FR-005**: The flake MUST expose `overlays.default` that adds `mcp-android`, `mcp-browser`, and (on darwin) `mcp-ios` to nixpkgs
- **FR-006**: The flake MUST expose `devShells.${system}.default` with all tools needed for contributing (nix, adb, node, python, etc.)
- **FR-007**: The flake MUST expose `checks.${system}.*` for smoke and E2E tests runnable via `nix flake check`
- **FR-008**: The flake MUST use `flake-utils` or equivalent for multi-platform system iteration
- **FR-009**: All source fetches MUST be pure — no impure network access during `nix build`

### Functional Requirements — Android Package (mcp-android)

- **FR-010**: mcp-android MUST wrap the `android-mcp` Python package from PyPI at a pinned exact version
- **FR-011**: mcp-android MUST include `adb` (from nixpkgs `android-tools`) on the wrapper's PATH
- **FR-012**: mcp-android MUST be buildable with `nix build .#mcp-android` in a pure Nix sandbox
- **FR-013**: mcp-android MUST be runnable with `nix run .#mcp-android` producing a stdio MCP server
- **FR-014**: mcp-android MUST pass all CLI arguments through to the upstream Python entrypoint transparently
- **FR-015**: mcp-android MUST support a `--check` flag (handled by the wrapper, not upstream) that verifies:
  - `adb` binary is on PATH and executable
  - `adb devices` returns at least one connected device/emulator
  - Prints structured diagnostic output with pass/fail per check and remediation hints on failure

### Functional Requirements — iOS Package (mcp-ios)

- **FR-020**: mcp-ios MUST wrap the `ios-simulator-mcp` npm package at a pinned exact version (≥1.5.2)
- **FR-021**: mcp-ios MUST set `meta.platforms = lib.platforms.darwin` so it fails at Nix evaluation time on non-darwin systems
- **FR-022**: mcp-ios MUST be buildable with `nix build .#mcp-ios` on macOS
- **FR-023**: mcp-ios MUST be runnable with `nix run .#mcp-ios` producing a stdio MCP server
- **FR-024**: mcp-ios MUST pass all CLI arguments through to the upstream Node entrypoint transparently
- **FR-025**: mcp-ios MUST support a `--check` flag that verifies:
  - `xcrun simctl` is available
  - At least one iOS simulator is available (booted or not)
  - Prints structured diagnostic output with remediation hints

### Functional Requirements — Browser Package (mcp-browser)

- **FR-030**: mcp-browser MUST wrap the `@playwright/mcp` npm package at a pinned exact version
- **FR-031**: mcp-browser MUST set `PLAYWRIGHT_BROWSERS_PATH` to point at nixpkgs-provided Chromium (aligned with the pinned Playwright version in nixpkgs)
- **FR-032**: The pinned `@playwright/mcp` version MUST be aligned with the nixpkgs `playwright-driver` version to avoid browser version mismatches
- **FR-033**: mcp-browser MUST be buildable with `nix build .#mcp-browser` in a pure Nix sandbox
- **FR-034**: mcp-browser MUST be runnable with `nix run .#mcp-browser` producing a stdio MCP server that launches headless Chromium by default
- **FR-035**: mcp-browser MUST pass all CLI arguments through to the upstream Node entrypoint transparently (e.g., `--browser firefox` if user provides their own browsers)
- **FR-036**: mcp-browser MUST support a `--check` flag that verifies:
  - Chromium binary is launchable (headless test)
  - `PLAYWRIGHT_BROWSERS_PATH` is correctly set
  - Prints browser version and structured diagnostic output

### Functional Requirements — Test Infrastructure

- **FR-040**: The flake MUST include a minimal Android test app (Java, minSdkVersion 28, targetSdkVersion 34) built entirely within Nix using `androidenv`
  Example: Single activity with a button labeled "Tap Me", a counter label showing "Count: 0", a text input field, and a scrollable list of items
- **FR-041**: The flake MUST include a minimal web test app (static HTML/CSS/JS, zero dependencies) for browser E2E tests
  Example: HTML page with a button, a counter display, a text input, and a link to a second page
- **FR-042**: Android E2E tests MUST spin up a headless Android emulator (x86_64, API 34 system image) using nixpkgs `androidenv.emulateApp`, install the test APK, start the mcp-android server, and exercise: screenshot, click (tap the button, verify counter increments), type (enter text in input), swipe (scroll the list), and accessibility tree read
- **FR-043**: Browser E2E tests MUST start the mcp-browser server, navigate to the test web app, and exercise: screenshot, click (tap button, verify counter), fill (type in input), and navigate (follow link to second page)
- **FR-044**: Browser E2E tests MUST run against all three Playwright browser engines: Chromium (from nixpkgs), Firefox, and WebKit (from Playwright's own download in CI)
- **FR-045**: iOS E2E tests MUST boot an iOS simulator, start the mcp-ios server, and exercise basic tools (screenshot, tap) on a macOS CI runner. The test target is a stock iOS app (e.g., Settings or a pre-installed sample app) since building a custom iOS app in Nix is impractical without Xcode's proprietary build system. If a custom test app is needed, it is built via `xcodebuild` in the macOS CI step, not via Nix.
- **FR-046**: All test output MUST be structured and agent-readable: `test-logs/<type>/<timestamp>/summary.json` with pass/fail/skip counts and `failures/<test-name>.log` with assertion details
- **FR-047**: All test suites MUST assert non-vacuous execution — a test run that reports 0 passed / 0 failed MUST be treated as a failure
- **FR-048**: Test apps MUST be exposed as flake packages: `packages.${system}.test-app-android` (APK) and `packages.${system}.test-app-web` (static site directory)

### Functional Requirements — CI/CD

- **FR-050**: The repo MUST include a GitHub Actions workflow that runs on every push and PR
- **FR-051**: CI MUST run `nix flake check` which executes all smoke tests
- **FR-052**: CI MUST run `nix build` for every package on Linux (x86_64-linux)
- **FR-053**: CI MUST run Android E2E tests on a KVM-enabled Linux runner (GitHub's standard runners support this for public repos)
- **FR-054**: CI MUST run browser E2E tests on Linux for all three browser engines (Chromium from Nix, Firefox and WebKit from Playwright download)
- **FR-055**: CI MUST run iOS E2E tests on a macOS runner with Xcode
- **FR-056**: CI MUST run security scanning: Gitleaks (secret detection), Trivy (vulnerability scanning), Semgrep (SAST)
- **FR-057**: CI MUST run Snyk and SonarCloud (free for public repos) for additional security coverage
- **FR-058**: CI MUST block merges on: test failures, security findings (critical/high), secrets detected, build failures
- **FR-059**: CI MUST verify non-vacuous test execution in every test job (0 tests = failure)
- **FR-060**: CI MUST include a Gitleaks pre-commit hook configured in the repo

### Functional Requirements — Packaging Constraints

- **FR-070**: All upstream versions MUST be pinned to exact versions (not semver ranges)
  Example: `android-mcp==1.2.3`, `ios-simulator-mcp@1.5.2`, `@playwright/mcp@1.0.5`
- **FR-071**: Upstream npm packages MUST be pinned in `flake.lock` via source fetch
- **FR-072**: The `@playwright/mcp` npm version MUST be chosen to align with whatever `playwright-driver` version nixpkgs ships, to avoid browser binary mismatches
- **FR-073**: Each package MUST use `makeWrapper` to wire native dependencies onto PATH and set required environment variables
- **FR-074**: Each package MUST produce a single executable entry point that runs the MCP server via stdio transport
- **FR-075**: Version updates are manual — the user bumps version pins in flake.nix and runs `nix flake update`

---

## Non-Goals

- **NG-001**: This project does NOT implement new MCP functionality — it wraps existing upstream servers only. Rationale: upstream servers are mature and actively maintained; duplicating their logic adds maintenance burden with no benefit.
- **NG-002**: This project does NOT include Android emulators, iOS simulators, or Xcode in the package outputs — users provide running targets. Rationale: these are massive, platform-specific tools that users already manage.
- **NG-003**: This project does NOT provide configuration abstraction over upstream MCP servers — all args pass through transparently. Rationale: wrapper-only principle; agents interact with upstream's native interface.
- **NG-004**: This project does NOT support Windows. Rationale: Nix flakes target Linux and macOS; Windows is not a supported Nix platform.
- **NG-005**: This project does NOT auto-update upstream versions. Rationale: user performs manual version bumps for controlled updates.
- **NG-006**: This project is NOT coupled to any specific AI agent framework — it's general-purpose MCP tooling. Rationale: any MCP-compatible agent can use it.
- **NG-007**: This project does NOT patch or fork upstream MCP servers — if upstream is broken, report upstream. Rationale: minimize maintenance surface.

---

## Key Entities

- **MCP Server Package**: A Nix derivation that wraps an upstream MCP server with its native dependencies, producing a single stdio executable
- **Test App**: A minimal application (Android APK or static HTML) used solely for E2E testing of MCP server functionality
- **Wrapper Script**: A shell script produced by `makeWrapper` that sets PATH, environment variables, and delegates to the upstream entrypoint
- **Pre-flight Check**: A `--check` mode added by the wrapper that validates prerequisites before starting the MCP server

---

## Success Criteria

- **SC-001**: `nix build .#mcp-android` succeeds on x86_64-linux in a pure sandbox [validates FR-012]
- **SC-002**: `nix build .#mcp-browser` succeeds on x86_64-linux in a pure sandbox [validates FR-033]
- **SC-003**: `nix build .#mcp-ios` succeeds on aarch64-darwin [validates FR-022]
- **SC-004**: `nix build .#mcp-ios` fails at evaluation time on x86_64-linux with a platform error [validates FR-021]
- **SC-005**: `nix run .#mcp-android` starts a stdio MCP server with adb on PATH [validates FR-013, FR-011]
- **SC-006**: `nix run .#mcp-browser` starts a stdio MCP server that can launch headless Chromium [validates FR-034, FR-031]
- **SC-007**: `nix run .#mcp-ios` starts a stdio MCP server on macOS [validates FR-023]
- **SC-008**: Android E2E test passes — emulator boots, test APK installs, MCP server exercises screenshot/click/type/swipe/accessibility [validates FR-042]
- **SC-009**: Browser E2E test passes against Chromium — server navigates, screenshots, clicks, fills, navigates links [validates FR-043]
- **SC-010**: Browser E2E test passes against Firefox and WebKit in CI [validates FR-044]
- **SC-011**: iOS E2E test passes on macOS CI — simulator boots, MCP server screenshots and taps [validates FR-045]
- **SC-012**: `mcp-android --check` reports correct pass/fail status for adb and device connectivity [validates FR-015]
- **SC-013**: `mcp-browser --check` reports Chromium launchability and version [validates FR-036]
- **SC-014**: `packages.${system}.default` includes all platform-appropriate packages [validates FR-004]
- **SC-015**: `overlays.default` makes packages available as `pkgs.mcp-*` [validates FR-005]
- **SC-016**: CI pipeline runs all tests, security scans, and blocks on failures [validates FR-050 through FR-059]
- **SC-017**: All test output is structured in `test-logs/` with summary.json [validates FR-046]
- **SC-018**: Zero critical/high vulnerabilities in security scans [validates FR-056, FR-057]
- **SC-019**: All CLI arguments pass through to upstream servers transparently [validates FR-014, FR-024, FR-035]
- **SC-020**: Test apps build as flake packages [validates FR-048]

---

## Infrastructure Decisions

### Error Handling
- **Approach**: Pre-flight `--check` flag on each wrapper with structured diagnostic output (checkmark/cross per check, remediation hints on failure). MCP server runtime errors pass through from upstream unchanged.
- **Rationale**: Agents need actionable diagnostics to self-fix. Upstream error pass-through respects wrapper-only principle.

### Configuration
- **Approach**: No configuration layer. Wrappers set PATH and environment variables at build time via `makeWrapper`. All runtime config is upstream's responsibility, passed through via CLI args.
- **Rationale**: Wrapper-only — adding config would duplicate upstream's interface.

### Logging
- **Approach**: No logging layer. Upstream servers log to stderr natively. Test infrastructure uses structured JSON output (summary.json).
- **Rationale**: Local tool preset; structured test output is sufficient for agent debugging.

### CI/CD
- **Platform**: GitHub Actions
- **Quality gates**: All tests pass, zero critical vulns, no secrets, non-vacuous test execution
- **Security scanning**: Tier 1 (Gitleaks, Trivy, Semgrep) + Snyk + SonarCloud (free for public repos)
- **Runners**: Standard Linux (x86_64, KVM-enabled) for Android + browser tests; macOS for iOS tests
- **Branching**: Direct-to-main (solo developer workflow)

### DX Tooling
- **Environment**: Nix flake devShell with all development tools
- **Scripts**: Provided via flake apps or a Makefile/Justfile — `test`, `test:android`, `test:browser`, `test:ios`, `check`, `build:all`, `lint`
- **Pre-commit**: Gitleaks hook for secret scanning

### Testing
- **Philosophy**: Real servers, real emulators, real browsers. No mocks at system boundaries.
- **Android**: Headless emulator via nixpkgs androidenv, x86_64, API 34 system image, minimal Java test app
- **Browser**: Chromium from nixpkgs for package; all three engines (Chromium, Firefox, WebKit) tested in CI
- **iOS**: Real simulator on macOS CI runner
- **Output**: Structured JSON in test-logs/ directory

---

## Assumptions

- Users have Nix with flakes enabled
- Linux users have KVM available for Android emulator tests (not required for using the package, only for running E2E tests)
- macOS users have Xcode installed for iOS package usage
- The GitHub repo is public (free CI runners, free security tools)
- nixpkgs-unstable is the upstream nixpkgs pin (most current playwright-driver version)
- Upstream MCP servers maintain backward-compatible stdio interfaces across minor versions
