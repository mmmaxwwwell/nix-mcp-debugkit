# nix-mcp-debugkit Constitution

## Core Principles

### I. Wrapper-Only
This project wraps existing upstream MCP servers — it does NOT implement new MCP functionality. Each package takes an upstream server and makes it work out of the box on Nix. If upstream is broken, report upstream; don't fork or patch unless absolutely necessary.

### II. Pure Nix Builds
All packages must build in the Nix sandbox with zero impure fetches. No `builtins.fetchurl` at build time, no network access during derivation builds. All sources pinned in `flake.lock` or as fixed-output derivations with known hashes. `nix build` and `nix flake check` must pass in a clean environment.

### III. Minimal Wrapping
Each wrapper does the minimum necessary: install the upstream package, wire native dependencies onto PATH (adb, xcrun, browsers), set required environment variables (PLAYWRIGHT_BROWSERS_PATH), and produce a single executable entry point. No configuration layers, no abstraction over upstream behavior, no custom flags.

### IV. Platform-Aware Packaging
Each package declares its supported platforms via `meta.platforms`. iOS is darwin-only. Android and browser work on Linux and macOS. Never build a package on an unsupported platform — fail at evaluation time, not at build time.

### V. Smoke-Testable
Every package includes a `passthru.tests` or contributes to `nix flake check` with a smoke test that verifies: (1) the wrapper script exists and is executable, (2) the entry point starts without crashing (e.g., prints help or version), (3) native dependencies are on PATH. Full integration tests (connecting to real emulators/browsers) are out of scope for CI.

### VI. Simplicity
Three packages, one flake. No monorepo tooling, no build orchestration, no code generation. The `flake.nix` is the entire build system. Each target gets one directory with one `default.nix`. If something can be done with standard nixpkgs builders, use them.

## Constraints

- **Upstream pinning**: Pin specific versions of upstream packages (PyPI version strings, npm semver). Update pins deliberately, not automatically.
- **No bundled runtimes**: Don't include Android emulators, Xcode, or iOS simulators. Document prerequisites; don't provide them.
- **flake-utils for multi-platform**: Use `flake-utils.lib.eachDefaultSystem` or equivalent for platform iteration. Don't hand-roll system loops.
- **MCP stdio transport**: All wrapped servers communicate via stdio. No HTTP servers, no WebSocket — stdio in, stdio out.

## Governance

The constitution governs all packaging decisions. When in doubt about whether to add complexity, don't. The test is: "does the upstream MCP server work correctly on NixOS after `nix run`?" If yes, we're done.

**Version**: 1.0.0 | **Ratified**: 2026-04-03
