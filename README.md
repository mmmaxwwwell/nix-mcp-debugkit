# nix-mcp-debugkit

[![CI](https://github.com/mmmaxwwwell/nix-mcp-debugkit/actions/workflows/ci.yml/badge.svg)](https://github.com/mmmaxwwwell/nix-mcp-debugkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Nix-packaged [MCP](https://modelcontextprotocol.io/) debug servers for Android, Browser, and iOS. Each package wraps an upstream MCP server with its native dependencies so it works out of the box on NixOS and Nix-enabled systems.

These servers let AI agents (Claude Code, Cursor, etc.) take screenshots, tap UI elements, read accessibility trees, and interact with running apps through the MCP protocol.

## Quick Start

Run any server directly without installing:

```bash
# Browser debugging (Linux & macOS)
nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-browser

# Android debugging (Linux)
nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-android

# iOS debugging (macOS only)
nix run github:mmmaxwwwell/nix-mcp-debugkit#mcp-ios
```

## Prerequisites

| Target | Platform | Requirements |
|--------|----------|--------------|
| `mcp-browser` | Linux, macOS | None (Chromium bundled via nixpkgs) |
| `mcp-android` | Linux | KVM enabled, Android emulator or device connected via ADB |
| `mcp-ios` | macOS only | Xcode with `xcrun simctl`, booted iOS simulator |

## Flake Usage

### As a flake input (individual packages)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    mcp-debugkit.url = "github:mmmaxwwwell/nix-mcp-debugkit";
  };

  outputs = { nixpkgs, mcp-debugkit, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          mcp-debugkit.packages.${system}.mcp-browser
          mcp-debugkit.packages.${system}.mcp-android
        ];
      };
    };
}
```

### Default package (all platform-appropriate servers)

```nix
# Includes mcp-android + mcp-browser on Linux
# Includes mcp-browser + mcp-ios on macOS
mcp-debugkit.packages.${system}.default
```

### Overlay

```nix
{
  inputs.mcp-debugkit.url = "github:mmmaxwwwell/nix-mcp-debugkit";

  outputs = { nixpkgs, mcp-debugkit, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ mcp-debugkit.overlays.default ];
      };
    in {
      # Now available as pkgs.mcp-android, pkgs.mcp-browser, etc.
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.mcp-browser pkgs.mcp-android ];
      };
    };
}
```

## Claude Code MCP Configuration

Add these to your Claude Code MCP config (`~/.claude/claude_desktop_config.json` or project-level `.mcp.json`):

### Browser

```json
{
  "mcpServers": {
    "browser": {
      "command": "nix",
      "args": ["run", "github:mmmaxwwwell/nix-mcp-debugkit#mcp-browser"]
    }
  }
}
```

### Android

```json
{
  "mcpServers": {
    "android": {
      "command": "nix",
      "args": ["run", "github:mmmaxwwwell/nix-mcp-debugkit#mcp-android"]
    }
  }
}
```

### iOS

```json
{
  "mcpServers": {
    "ios": {
      "command": "nix",
      "args": ["run", "github:mmmaxwwwell/nix-mcp-debugkit#mcp-ios"]
    }
  }
}
```

## Pre-flight Checks (`--check`)

Each server supports a `--check` flag that verifies prerequisites before starting. This is useful for agents to diagnose issues programmatically.

```bash
mcp-browser --check   # Verifies PLAYWRIGHT_BROWSERS_PATH and Chromium launch
mcp-android --check   # Verifies adb on PATH and connected devices
mcp-ios --check       # Verifies xcrun simctl and available simulators
```

Exit code `0` means all checks passed. Non-zero means a prerequisite is missing, with actionable remediation hints printed to stdout.

## Troubleshooting

### KVM not available (Android)

Android emulator requires KVM. If you see "KVM not available":

```bash
# Check KVM support
ls -la /dev/kvm

# On NixOS, ensure KVM is enabled:
# virtualisation.libvirtd.enable = true;  (or boot.kernelModules = [ "kvm-intel" ] / "kvm-amd")
```

### No Android devices connected

```bash
# Start an emulator
emulator -avd <name> -no-window

# Or connect a physical device and verify
adb devices
```

### Browser version mismatch

The Playwright version is pinned to match the nixpkgs `playwright-driver` browser binaries. If you see version mismatch errors, ensure you're using the Nix-wrapped `mcp-browser` (which sets `PLAYWRIGHT_BROWSERS_PATH` automatically) rather than a globally installed version.

### Xcode / iOS simulator not available

```bash
# Install Xcode CLI tools
xcode-select --install

# List available simulators
xcrun simctl list devices

# Boot a simulator
xcrun simctl boot "iPhone 15"
```

### Chromium fails to launch

If Chromium crashes on launch, ensure your system supports headless mode. The Nix package runs Chromium with `--headless` by default. On systems without a display server, this should work without additional configuration.

## CI Setup for Contributors

The CI pipeline runs on GitHub Actions and includes lint, build, E2E tests, and security scanning.

### Required GitHub Secrets

#### SNYK_TOKEN

1. Sign up at [snyk.io](https://snyk.io) (free for open-source)
2. Go to **Account Settings** > **API Token**
3. Copy the token
4. Add as a repository secret: **Settings** > **Secrets and variables** > **Actions** > **New repository secret** > Name: `SNYK_TOKEN`

#### SONAR_TOKEN

1. Sign up at [sonarcloud.io](https://sonarcloud.io) (free for public repos)
2. Import your GitHub repository
3. Go to **My Account** > **Security** > **Generate Tokens**
4. Copy the token
5. Add as a repository secret: **Settings** > **Secrets and variables** > **Actions** > **New repository secret** > Name: `SONAR_TOKEN`

#### Optional Secrets

- `GITLEAKS_LICENSE` — Required for org repos using Gitleaks action. Not needed for personal repos.
- `SEMGREP_APP_TOKEN` — Optional; enables Semgrep CI integration with the Semgrep dashboard.

## Contributing

1. Fork the repository
2. Enter the dev shell: `nix develop`
3. Make your changes
4. Run lint checks: `nix develop --command statix check . && nix develop --command deadnix . && nix develop --command shellcheck --severity=warning tests/*.sh`
5. Run smoke tests: `nix flake check`
6. Run the local security scan: `security-scan.sh`
7. Open a pull request

## License

[MIT](LICENSE)
