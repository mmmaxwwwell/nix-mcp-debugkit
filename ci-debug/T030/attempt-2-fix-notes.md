# Attempt 2 — Fix Notes (Final)

## Summary

All 6 categories of CI fixes identified in the diagnosis are **already committed** in local
main branch (commits `eae1a55` through `1276b8e`). The CI run referenced in the diagnosis
(`23970313066`) ran on commit `ff426aa`, which **predates all fix commits**. No additional
code changes are needed — the runner just needs to push the existing commits to trigger a
new CI run.

## CI run timeline

- **CI run 23970313066**: triggered by commit `ff426aa` (dependabot.yml fix only)
- **Fix commits** (all after `ff426aa`, all on local main, not yet pushed):
  - `eae1a55` fix(T030): fix 6 categories of CI workflow failures
  - `5a6c4f0` fix(T030): add build prerequisites and env vars to E2E CI jobs
  - `aea52b9` fix(T030): remove unused E2E checks from flake.nix and dead android emulator bindings
  - `1276b8e` fix(T030): correct Chromium E2E test-logs path in CI verification step

## Verification: all 6 diagnosis categories are addressed

| # | Category | Fix in ci.yml | Commit |
|---|----------|---------------|--------|
| 1 | Chromium sandboxing | `PLAYWRIGHT_CHROMIUM_SANDBOX: "0"` env on e2e-browser steps | eae1a55 |
| 2 | macOS Nix install | `cachix/install-nix-action@v30` for macOS jobs | eae1a55 |
| 3 | Invalid SARIF | All fallback SARIF includes `$schema`, `version`, `tool.driver` | eae1a55 |
| 4 | Trivy version | `aquasecurity/trivy-action@v0.28.0` (v-prefixed; tag confirmed to exist) | eae1a55 |
| 5 | Missing secrets | `if: env.*_TOKEN != ''` guards + `continue-on-error: true` | eae1a55 |
| 6 | E2E prereqs | Build steps + env var exports before test scripts | 5a6c4f0 |

Additional fixes:
- E2E checks removed from `flake.nix` (smoke-test no longer hits Chromium sandbox) | aea52b9
- Dead `androidEmulatorComposition`/`androidEmulatorSdk` bindings removed from flake.nix | aea52b9
- Chromium E2E test-logs path corrected in CI verification step | 1276b8e

## Fast checks (all pass — re-verified 2026-04-04)

| Command | Result |
|---------|--------|
| `statix check .` | PASS |
| `deadnix .` | PASS |
| `shellcheck --severity=warning tests/*.sh` | PASS |
| `gh api` trivy-action v0.28.0 tag exists | CONFIRMED |
| E2E checks removed from flake.nix | CONFIRMED (only comment at line 93) |
| smoke.sh doesn't launch browsers | CONFIRMED (only checks binary/help/check) |

## Action needed

The runner should push the existing 56 local commits to trigger a new CI run. No new code
changes are required — all diagnosis items are already addressed.
