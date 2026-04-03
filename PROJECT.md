# nix-mcp-debugkit — Project Prompt

## What this is

A single Nix flake repo that wraps three existing MCP (Model Context Protocol) servers for agent debugging of running app targets. Each wrapper packages an upstream MCP server with its native dependencies so it works out of the box on NixOS and nix-enabled systems.

Agents (Claude Code, Cursor, etc.) use these MCP servers to take screenshots, tap UI elements, read accessibility trees, and interact with running apps — replacing the "blind scripting" problem where agents write E2E tests without seeing what's on screen.

## Upstream MCP servers we wrap

| Target | Upstream | License | Pin version | Why this one |
|--------|----------|---------|-------------|--------------|
| **Android** | [CursorTouch/Android-MCP](https://github.com/CursorTouch/Android-MCP) | MIT | PyPI `android-mcp` | Python-based (simple Nix packaging), ADB-only, minimal deps |
| **iOS** | [joshuayoes/ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp) | MIT | npm, semver `v1.5.2`+ | Past 1.0, focused, macOS-only (correct constraint for iOS sims) |
| **Browser** | [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp) | Apache-2.0 | npm `@playwright/mcp` | 30k+ stars, Microsoft-backed, Chrome/Firefox/WebKit |

## Repo structure

```
nix-mcp-debugkit/
├── flake.nix           # Top-level flake exposing all packages
├── flake.lock
├── android/            # Wraps android-mcp + adb from nixpkgs
│   └── default.nix
├── ios/                # Wraps ios-simulator-mcp + xcrun (darwinOnly)
│   └── default.nix
├── browser/            # Wraps playwright-mcp + browsers from nixpkgs
│   └── default.nix
├── PROJECT.md          # This file
└── README.md           # Human-facing docs
```

## Flake outputs

```nix
# Linux (x86_64-linux, aarch64-linux)
packages.x86_64-linux.mcp-android
packages.x86_64-linux.mcp-browser
packages.aarch64-linux.mcp-android
packages.aarch64-linux.mcp-browser

# macOS (aarch64-darwin)
packages.aarch64-darwin.mcp-android
packages.aarch64-darwin.mcp-browser
packages.aarch64-darwin.mcp-ios       # darwin only
```

Each package is a standalone executable that runs the MCP server via stdio transport.

## How consumers use it

### As a flake input in a project

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    mcp-debugkit.url = "github:mmmaxwwwell/nix-mcp-debugkit";
  };

  outputs = { self, nixpkgs, mcp-debugkit, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          mcp-debugkit.packages.${system}.mcp-android
          mcp-debugkit.packages.${system}.mcp-browser
        ];
      };
    };
}
```

### Direct run

```bash
nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-android
nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-browser
nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-ios  # macOS only
```

### In Claude Code MCP config

```json
{
  "mcpServers": {
    "android": {
      "command": "nix",
      "args": ["run", "github:mmmaxwwwell/nix-mcp-debugkit#mcp-android"]
    },
    "browser": {
      "command": "nix",
      "args": ["run", "github:mmmaxwwwell/nix-mcp-debugkit#mcp-browser"]
    }
  }
}
```

## Implementation details per target

### Android (`mcp-android`)

**Upstream**: `android-mcp` Python package from PyPI
**Native deps**: `android-tools` (adb) from nixpkgs
**Packaging approach**: Use `python3Packages.buildPythonApplication` or wrap with `uv2nix`/`pyproject.nix` to build from PyPI source. Ensure `adb` is on PATH via `makeWrapper`.

Key considerations:
- `adb` must be in PATH — wrap the Python entrypoint with `makeWrapper --prefix PATH : ${android-tools}/bin`
- The upstream uses `uvx` for install — we bypass this entirely and build from source
- Android emulator itself is NOT included (too heavy) — user provides their own running emulator/device
- Test: `adb devices` should list a device, then the MCP server connects to it

### iOS (`mcp-ios`)

**Upstream**: `ios-simulator-mcp` npm package
**Native deps**: Xcode CLI tools (xcrun, simctl) — these come with Xcode on macOS
**Packaging approach**: Use `buildNpmPackage` from nixpkgs. Only build on darwin systems.
**Platform constraint**: `meta.platforms = lib.platforms.darwin;`

Key considerations:
- `xcrun simctl` must be in PATH — on macOS with Xcode installed, it already is
- The flake should not try to provide Xcode (not possible via Nix) — just document the prerequisite
- Wrap the node entrypoint to ensure correct PATH
- Test: `xcrun simctl list devices` should show simulators

### Browser (`mcp-browser`)

**Upstream**: `@playwright/mcp` npm package
**Native deps**: Chromium and/or Firefox from nixpkgs
**Packaging approach**: Use `buildNpmPackage`. Set `PLAYWRIGHT_BROWSERS_PATH` to point at nixpkgs-provided browsers instead of letting Playwright download its own.

Key considerations:
- This is the hardest one. Playwright normally downloads its own browser binaries, which breaks in the Nix sandbox.
- Solution: use `playwright-driver` from nixpkgs or set `PLAYWRIGHT_BROWSERS_PATH` to a derivation containing the correct browser builds
- Reference implementations exist: [benjaminkitt/nix-playwright-mcp](https://github.com/benjaminkitt/nix-playwright-mcp) and [akirak/nix-playwright-mcp](https://github.com/akirak/nix-playwright-mcp) — study these for the browser path wiring
- There is a known nixpkgs issue with playwright packaging: https://github.com/nixos/nixpkgs/issues/443704 — the wrapper must work around this
- Test: the MCP server should be able to launch a headless Chromium and take a screenshot

## Build order

Start with **Android** (simplest — Python + adb, no browser gymnastics), then **iOS** (Node + darwin constraint), then **Browser** (hardest — Playwright browser path wiring).

## Quality requirements

- Each package must be buildable with `nix build .#mcp-android` etc.
- Each package must be runnable with `nix run .#mcp-android` etc.
- Pin upstream versions in flake.lock (for npm packages) or as version strings (for PyPI)
- Include a basic smoke test in the flake (`passthru.tests` or `nix flake check`)
- No impure fetches — everything must build in the Nix sandbox
- Use `flake-utils` or `systems` for multi-platform support

## What this is NOT

- This is NOT a new MCP server implementation — we wrap existing, mature upstream servers
- This does NOT include emulators/simulators themselves — the user provides running targets
- This does NOT include the Android SDK or Xcode — those are prerequisites the user manages
- This is NOT coupled to agent-framework or spec-kit — it's a general-purpose tool
