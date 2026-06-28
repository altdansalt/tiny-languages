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

## 2026-06-28 — Data pipeline & arch strategy

### List mining (`scripts/fetch_lists.sh` → `scripts/enrich.py`)
`fetch_lists.sh` pulls each source list's README via the GitHub API and extracts
every `github.com/<owner>/<repo>` link → `data/pool_repos.txt` (~1.9k repos).
`enrich.py` resolves them in **batched GraphQL** (50/query, ~40 calls total
instead of ~1900 REST calls), records `data/pool.tsv`, and emits a ranked
`data/shortlist.tsv` of candidates not already in `candidates.tsv`.

Tininess score favors: small `diskUsage` (<1 MB best), a portable implementation
language (C/C++/Rust/Go/Zig/…), interpreter/compiler/lang keywords, some traction
(stars), and penalizes archived repos. The shortlist is the queue for new recipes.

### amd64 emulation for arch-locked languages
The host is arm64, but `container --arch amd64` works (Rosetta) — confirmed. For
languages whose source only knows x86 (`__x86_64__`, x86 asm) we add a recipe-dir
`arch` file containing `amd64`; `build.sh` then builds *and* smoke-runs under
emulation. First use: **femtolisp** (its `llt` headers also need glibc's
`__gnu_linux__`, so its recipe is debian + amd64). Native arm64/musl stays the
default; emulation is the escape hatch, noted per-recipe.

### glibc fallback
Alpine/musl is the default and preferred (harsher = more portable). When a project
genuinely needs glibc we use `debian:bookworm-slim` and say why in the recipe
header. So far: **tcc** (musl `wchar_t` redefinition in its runtime lib) and
**femtolisp** (`__gnu_linux__`).

## Roads not taken (so far)

- **One mega-Dockerfile for everything** — rejected: poor caching, one failure
  blocks all, hard to read. Per-recipe is the unit of work.
- **Building on the host directly** — rejected: not reproducible, pollutes host,
  doesn't prove portability. Containers only.
- **Trusting awesome-list "tiny" tags** — rejected: many are stale or aspirational.
  Build it or it doesn't count.
