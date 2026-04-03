# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

## T001 — flake.nix skeleton
- Nix store permissions may not be available in sandboxed CI/agent environments — `nix flake show` and `nix-instantiate --parse` both need store access. Syntax validation may need to happen at phase validation time.
- `eachDefaultSystem` output is merged with `//` for non-per-system attrs like `overlays.default`.

## T002 — tests/common.sh
- `shellcheck` is not on PATH by default; it's available at a nix store path. The `nix develop` shell (from T001) will provide it. For direct invocation outside devshell, use the store path.
- Bash arithmetic `(( var++ ))` returns exit code 1 when the variable was 0 before increment; wrap in `|| true` to avoid `set -e` traps.

## T003 — tests/smoke.sh
- Nix `checks` derivations using `runCommand` need `nativeBuildInputs` for all required tools — packages are not on PATH by default in the build sandbox.
- `${./tests}` in Nix copies the local `tests/` directory into the Nix store, making it available in the sandbox build environment.

## T005 — android/default.nix
- `fastmcp` and `mcp` are in nixpkgs-unstable (as of early 2026). `uiautomator2` and `adbutils` are NOT — must be built inline.
- `uiautomator2` uses `poetry-dynamic-versioning` as build backend; patch pyproject.toml to use plain `poetry-core` since version is already set in the sdist.
- `adbutils` uses `pbr` for builds; set `PBR_VERSION = version;` to avoid git-based version detection in the Nix sandbox.

## T006 — android/check.sh
- `wrapProgram` renames the original binary to `.android-mcp-wrapped` and creates a new wrapper script. To add a `--check` shim, rename the wrapProgram output to `.android-mcp-launch` and create a new outer wrapper.
- The outer wrapper must re-set PATH (e.g., `android-tools/bin`) since exec-ing check.sh bypasses the wrapProgram environment setup.

