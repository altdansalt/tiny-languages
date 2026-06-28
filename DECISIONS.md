# Decisions & conventions

Running log of design decisions, conventions, and roads not taken.

## 2026-06-28 — Project setup

### "Known-working" means a real container build + smoke test
Every language in the table is verified by an actual build in a clean, minimal
Linux container via Apple's `container` CLI (v0.5.0), not by reputation. Host is
macOS arm64, so default container arch is arm64 — a good proxy for "runs on a
Raspberry Pi" (also ARM). x86 / wasm cross-checks are added per-language where
relevant.

### Recipe convention
Each candidate gets `recipes/<name>/Dockerfile` that:
1. Starts from a **minimal base** (`alpine:3.20` preferred; `debian:bookworm-slim`
   when glibc/toolchain demands it).
2. Builds the language from source (pinned to a tag/commit where practical).
3. Runs a **smoke test as a `RUN` step** — so a failed smoke makes the *build*
   fail. This gives a single clean signal: `container build` exit 0 == working.
4. Prints a `BINSIZE <bytes> <name>` marker so the harness records artifact size.
5. Sets `CMD` to the smoke command so the harness can re-run and capture output.

Rationale: folding the smoke test into the build makes the result reproducible and
binary. No flaky "did the test run separately" state.

### Outcome vocabulary (status in candidates.tsv / results JSON)
- `untried` — no recipe attempted yet
- `ok` — builds and smoke passes
- `partial` — builds but smoke is weak / a sub-feature failed
- `fail` — does not build or smoke fails (log kept; reason recorded)
- `skip` — intentionally excluded (with reason)

### Why Alpine + the `BINSIZE` marker
Alpine (musl) is the harsher target: code that builds on musl is more portable and
genuinely "tiny" in dependency terms. musl-static binaries are the closest analog to
"drop it on a bare RPi / into a minimal wasm-ish sandbox." When a project genuinely
needs glibc, we fall back to debian-slim and note it.

## Roads not taken (so far)

- **One mega-Dockerfile for everything** — rejected: poor caching, one failure
  blocks all, hard to read. Per-recipe is the unit of work.
- **Building on the host directly** — rejected: not reproducible, pollutes host,
  doesn't prove portability. Containers only.
- **Trusting awesome-list "tiny" tags** — rejected: many are stale or aspirational.
  Build it or it doesn't count.
