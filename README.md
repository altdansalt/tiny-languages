# tiny-languages

A curated, **verified** collection of small compilers and interpreters that build
and run inside a minimal container.

"Tiny" has no formal definition here. The working criteria:

- Can plausibly run in a **WebAssembly runtime**, or
- Can run on a **barebones Raspberry Pi** (small footprint, few dependencies).

In practice that means: a small codebase, few/no heavy dependencies, fast to build,
and a modest runtime memory footprint.

## What this repo is

This is a **data pipeline**. Starting from seed lists (and curated knowledge), we:

1. **Gather** candidate languages from awesome-lists and other sources (`scripts/`, `data/`).
2. **Recipe** each one: a minimal build+smoke-test inside a container (`recipes/`).
3. **Build & test** in clean, minimal containers via Apple's `container` CLI (`scripts/build.sh`).
4. **Record** results — what built, what ran, what didn't, and why (`results/`, `FINDINGS.md`).

Every "known-working" claim in this repo is backed by an actual container build+run.

## Layout

| Path | Purpose |
|------|---------|
| `seeds/lists.md` | Source lists we mine for candidates |
| `seeds/candidates.tsv` | The master candidate table (name, repo, lang, category, status) |
| `recipes/<name>/` | Per-language build recipe (Dockerfile + smoke test) |
| `scripts/` | Pipeline scripts (fetch, parse, build, report) |
| `results/` | Per-language build/test result JSON |
| `data/` | Raw fetched data from source lists |
| `DECISIONS.md` | Decisions, conventions, roads not taken |
| `FINDINGS.md` | Running log of what worked and what didn't |

## Environment

- Host: macOS (arm64), Apple `container` CLI 0.5.0.
- Builds run in Linux containers (default arch = host arch, arm64).
- WASM targets validated with `wasmtime` / `wasi-sdk` where relevant.

## Status

See `seeds/candidates.tsv` for the live table and `results/` for machine-readable
build outcomes. `scripts/report.py` regenerates the summary in `FINDINGS.md`.
