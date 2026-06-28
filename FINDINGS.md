# Findings

Running log of build/test outcomes. Machine-readable results live in `results/*.json`;
`scripts/report.py` regenerates the summary table below.

## Summary

<!-- REPORT:BEGIN -->
| name | outcome | build (s) | binary | smoke |
|------|---------|-----------|--------|-------|
| lua  | ok      | 61        | 370 KB | ok Lua 5.5 |
<!-- REPORT:END -->

## Narrative log

### 2026-06-28
- **lua** ✅ — `github.com/lua/lua`, alpine + build-base, plain `make`. Builds in
  ~60s (mostly base-image pull), 370 KB binary, runs `print(_VERSION)` → Lua 5.5.
  The reference "it works" case that proves the pipeline.
