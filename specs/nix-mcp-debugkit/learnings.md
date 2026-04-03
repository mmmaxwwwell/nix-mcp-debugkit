# Learnings

Discoveries, gotchas, and decisions recorded by the implementation agent across runs.

---

## T001 — flake.nix skeleton
- Nix store permissions may not be available in sandboxed CI/agent environments — `nix flake show` and `nix-instantiate --parse` both need store access. Syntax validation may need to happen at phase validation time.
- `eachDefaultSystem` output is merged with `//` for non-per-system attrs like `overlays.default`.

## T002 — tests/common.sh
- `shellcheck` is not on PATH by default; it's available at a nix store path. The `nix develop` shell (from T001) will provide it. For direct invocation outside devshell, use the store path.
- Bash arithmetic `(( var++ ))` returns exit code 1 when the variable was 0 before increment; wrap in `|| true` to avoid `set -e` traps.

