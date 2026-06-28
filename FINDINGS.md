# Findings

Running log of build/test outcomes. Machine-readable results live in `results/*.json`;
`scripts/report.py` regenerates the summary table below.

## Summary

<!-- REPORT:BEGIN -->
| name | outcome | build (s) | binary | smoke |
|------|---------|-----------|--------|-------|
| berry | ok | 11 | 370 KB | ok-berry |
| chibi-scheme | ok | 16 | 234 KB | ok-chibi |
| clox | ok | 6 | 74 KB | 3 |
| cproc | fail | 4 | — |  |
| fe | ok | 3 | 74 KB | ok-fe |
| femtolisp | fail | 2 | — |  |
| goawk | ok | 16 | 3.9 MB | ok-goawk |
| gravity | ok | 3 | 438 KB | ok-gravity RESULT: NULL (in 0.0157 ms) |
| janet | ok | 29 | 2.2 MB | ok janet |
| lua | ok | 3 | 362 KB | ok Lua 5.5 |
| m4 | ok | 36 | 1.1 MB | ok-m4 |
| micropython | ok | 11 | 258 KB | ok-mpy |
| mruby | ok | 88 | 9.0 MB | ok-mruby |
| onetrueawk | ok | 6 | 491 KB | ok-awk |
| pforth | ok | 5 | 272 KB | PForth V2.2.0, LE, built Jun 28 2026 14:02:33 (s |
| picol | ok | 4 | 73 KB | ok-picol |
| pocketlang | ok | 3 | 1.1 MB | ok-pocket |
| quickjs-ng | ok | 34 | 1.3 MB | ok-qjs |
| squirrel | ok | 12 | 73 KB | ok-squirrel |
| tcc | fail | 15 | — |  |
| umka | ok | 12 | 322 KB | ok-umka |
| wasm3 | ok | 4 | 236 KB | Result: 55 |
| wren | ok | 6 | 196 KB | ok-wren |
<!-- REPORT:END -->

## Narrative log

### 2026-06-28
- **lua** ✅ — `github.com/lua/lua`, alpine + build-base, plain `make`. Builds in
  ~60s (mostly base-image pull), 370 KB binary, runs `print(_VERSION)` → Lua 5.5.
  The reference "it works" case that proves the pipeline.
- **janet** ✅ — plain `make`, musl-friendly (upstream recommends Alpine). 2.2 MB.
- **wren** ✅ — the premake makefiles hardcode `-m64` (x86-only); `sed` it out and
  `make -C projects/make config=release_64bit wren_test` works on arm64. 196 KB.
- **chibi-scheme** ✅ — must `make install` to a prefix; running uninstalled with
  `SEXP_USE_DL=0` makes it mis-read a binary as Scheme (`undefined variable |ELF`).
  Smoke via `-e` (not stdin) to avoid REPL prompt noise. 234 KB.
- **tcc** ❌ (deferred) — `--config-musl` build dies in `libtcc1/bcheck.o` with
  `incompatible redefinition of wchar_t` on musl. Retry on a debian/glibc base.
- **cproc** ❌ (deferred) — builds cproc + QBE, but `qbe` rejects IR keyword
  `extern` that the cproc frontend emits → cproc/qbe version skew. Need matching
  pinned commits. (Also found: the `8l/qbe` mirror has a `$define` typo on its
  aarch64 Makefile branch; `michaelforney/qbe` fixes that but the skew remains.)
- **femtolisp** ❌ (deferred) — `llt/dtypes.h`/`utils.h` only recognize
  `__x86_64__` + `__gnu_linux__`; `#error unknown platform/architecture` on
  arm64/musl. Good candidate for an **amd64-emulation** build (confirmed working:
  `container run --arch amd64 … uname -m` → `x86_64`).

#### Batch 3 — 13 more verified (20 green total)
- ✅ **clox** (`make clox`), **fe** (`-DFE_STANDALONE`, single file), **picol**
  (single-file Tcl, `cc picol.c`), **onetrueawk** (needs `bison`; binary is
  `a.out`), **m4** (built from the release **tarball** — git needs a heavy gnulib
  bootstrap), **berry** (cmake, `-DUSE_READLINE_LIB=0`), **goawk** (Go),
  **squirrel** (cmake, C++), **quickjs-ng** (cmake), **pocketlang**, **gravity**,
  **umka**, **pforth** (cmake; use the `pforth_standalone` target in `fth/`),
  **micropython**, **mruby**, **wasm3**.
- Recurring **x86-ism on arm64**: hardcoded `-m64` (wren) / `-malign-double`
  (umka) in makefiles → `sed` them out. A reusable signal for "tiny C" projects
  that only ever got built on x86.
- **musl gaps**: wasm3's optional WASI backend pulls libuv needing
  `linux/errqueue.h` → build with `-DBUILD_WASI=none`. micropython's *standard*
  unix variant pulls berkeley-db needing `sys/cdefs.h` (absent on musl) → build
  `VARIANT=minimal` (also truer to "tiny", 258 KB).
- **Smoke-test gotchas worth recording**: gravity uses `System.print` (not
  `print`); pocketlang needs `print(...)` call syntax; clox/chibi REPL prefixes
  stdout with prompts (run a file or use `-e`); wasm3 writes its result to
  **stderr** (merge `2>&1`); several cmake projects drop the binary somewhere
  unexpected (`find`-and-copy beats guessing the path).
- Toolchain notes: mruby needs `ruby-rake` (Alpine's `ruby` pkg omits rake);
  onetrueawk's "yacc" is `bison`.
