# Interview Notes — nix-mcp-debugkit

**Preset**: local
**Date**: 2026-04-03
**Nix available**: yes

## Project Description

A Nix flake wrapping three upstream MCP servers (Android, iOS, Browser) with native dependencies for out-of-the-box use on NixOS/Nix systems. Primary consumers are AI agents that use MCP for visual debugging of running applications.

## Key Decisions

### Upstream version pinning → Exact versions
User chose exact version pins over semver ranges. Rationale: maximum reproducibility; Nix flake.lock handles the reproducibility layer, and known-good versions prevent surprise breakage.

### Browser scope → All three engines (Chromium, Firefox, WebKit)
User wants first-class support for everything the upstream supports. Chromium ships via nixpkgs; Firefox and WebKit are tested in CI via Playwright's own download mechanism (nixpkgs only packages Chromium for playwright-driver as of 2026-04).

### Playwright version alignment → Align npm pin to nixpkgs playwright-driver
Avoids the known browser version mismatch issue (nixpkgs#443704). The @playwright/mcp version is chosen to match whatever playwright-driver nixpkgs ships.

### Android test app → Minimal Java app built with Nix
User explicitly rejected Flutter (too heavy). Minimal Java Android app with minSdkVersion 28 (covers 95%+ non-EOL devices), targetSdkVersion 34, x86_64 for emulator performance. App includes: button, counter label, text input, scrollable list — exercises all MCP tools (click, type, swipe, state-read).

### Android emulator in tests → Yes, full E2E with real emulator
User was emphatic: "put the fucking emulator into it, you're using flakes you can do that easy." Headless emulator via nixpkgs androidenv.emulateApp. Requires KVM on Linux.

### CI runners → GitHub larger Linux runners (KVM) + macOS runners
Public repo gets free KVM-enabled Linux runners for Android emulator E2E. macOS runners for iOS E2E (10x cost but user said "whatever works for cicd").

### Browser E2E testing → All three engines in CI
Chromium tested via Nix-packaged browsers. Firefox and WebKit tested in CI using Playwright's own browser installer (non-Nix step). This is a pragmatic compromise since nixpkgs doesn't package Firefox/WebKit for Playwright.

### iOS testing → Full E2E on macOS CI
Real simulator, real MCP server, screenshot and tap verification. iOS test app approach TBD (Xcode's proprietary nature makes Nix-built iOS apps impractical — likely use a pre-built minimal app or xcodebuild in CI).

### Flake outputs → Individual + default + overlay
- `packages.*.mcp-android`, `packages.*.mcp-browser`, `packages.*.mcp-ios` (individual)
- `packages.*.default` (all packages for the system)
- `overlays.default` (adds packages to nixpkgs)
- `checks.*` for E2E tests
- `devShells.*.default` for contributors

### Error handling → Pre-flight --check with agent-friendly diagnostics
Each wrapper supports `--check` that validates prerequisites with structured output (checkmarks, remediation hints). Agents are the primary consumers — they need to parse errors and self-fix. Runtime errors pass through from upstream unchanged.

### Arguments → Transparent passthrough
Wrappers pass all CLI arguments through to upstream. The wrapper's job is dependency wiring, not behavior configuration.

### License → MIT
Compatible with all three upstreams (MIT, MIT, Apache-2.0).

### Repo visibility → Public
Enables free GitHub Actions runners (including KVM-enabled), free Snyk, free SonarCloud.

### nixpkgs pin → nixpkgs-unstable
Most up-to-date playwright-driver version, which the @playwright/mcp pin must align with.

### Version updates → Manual
User bumps versions locally; no automated Dependabot-style PRs. Agents handle updates when asked.

### Security scanning → Maximum free coverage
Tier 1 (Gitleaks, Trivy, Semgrep) + Snyk + SonarCloud. "If it's free to public projects use that shit."

## Rejected Alternatives

- **Flutter test app**: Rejected — too heavy a build closure for a simple test fixture. Java is lighter and builds natively with nixpkgs androidenv.
- **Semver ranges for upstream pins**: Rejected — exact pins preferred for reproducibility.
- **Chromium-only browser support**: Rejected — user wants all engines the upstream supports.
- **Stub process testing**: Rejected — "everything that we can get through nix should test against a real server." Real emulators, real browsers, no fakes.
- **Manual README docs beyond basics**: Not discussed — README covers quick install, prerequisites, usage examples, troubleshooting.

## User Priorities

1. **Comprehensive E2E testing** — the #1 priority. Agents are doing the development work and need high-quality tests to find bugs without human intervention.
2. **Real runtime testing** — no mocks, no stubs. Real emulators, real browsers, real MCP servers.
3. **All browser engines** — first-class support for everything upstream supports.
4. **Agent-friendly diagnostics** — structured error output agents can parse and act on.
5. **Nix purity** — everything builds in the sandbox, no impure fetches.

## Surprising/Non-obvious Requirements

- User wants the Android emulator included in the test infrastructure, built entirely within Nix — not just smoke tests against a pre-existing emulator.
- User wants all three Playwright browser engines tested despite nixpkgs only packaging Chromium — requires a hybrid Nix + Playwright-download approach in CI.
- The "local" preset was chosen but testing scope is closer to "enterprise" — user explicitly said to ignore the question limit and ask as many questions as needed.
- Primary consumers are AI agents, not humans — this shapes error handling, output format, and testing philosophy toward machine-readability.
