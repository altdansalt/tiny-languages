# Findings

Running log of build/test outcomes. Machine-readable results live in `results/*.json`;
`scripts/report.py` regenerates the summary table below.

## Summary

<!-- REPORT:BEGIN -->
| name | outcome | build (s) | binary | smoke |
|------|---------|-----------|--------|-------|
| ape | ok | 3 | 230 KB | ok-ape |
| atto | fail | 10 | — |  |
| berry | ok | 11 | 370 KB | ok-berry |
| brainfuck | ok | 5 | 73 KB | Hello World! |
| chibi-scheme | ok | 16 | 234 KB | ok-chibi |
| clox | ok | 6 | 74 KB | 3 |
| cproc | fail | 4 | — |  |
| fe | ok | 3 | 74 KB | ok-fe |
| femtolisp | ok | 23 | 203 KB | ok-femto |
| goawk | ok | 16 | 3.9 MB | ok-goawk |
| gravity | ok | 3 | 438 KB | ok-gravity RESULT: NULL (in 0.0157 ms) |
| janet | ok | 29 | 2.2 MB | ok janet |
| lci | ok | 9 | 1.6 MB | ok-lci |
| lua | ok | 3 | 362 KB | ok Lua 5.5 |
| m4 | ok | 36 | 1.1 MB | ok-m4 |
| mac | ok | 3 | 73 KB | popped 11 done |
| micropython | ok | 11 | 258 KB | ok-mpy |
| mruby | ok | 88 | 9.0 MB | ok-mruby |
| onetrueawk | ok | 6 | 491 KB | ok-awk |
| partcl | ok | 4 | 73 KB | result> 42 |
| pforth | ok | 5 | 272 KB | PForth V2.2.0, LE, built Jun 28 2026 14:02:33 (s |
| picol | ok | 4 | 73 KB | ok-picol |
| pocketlang | ok | 3 | 1.1 MB | ok-pocket |
| quickjs-ng | ok | 34 | 1.3 MB | ok-qjs |
| squirrel | ok | 12 | 73 KB | ok-squirrel |
| tcc | ok | 15 | 418 KB | ok-tcc |
| ubasic | ok | 4 | 74 KB | 42 |
| umka | ok | 12 | 322 KB | ok-umka |
| wasm3 | ok | 4 | 236 KB | Result: 55 |
| wren | ok | 6 | 196 KB | ok-wren |
| yoctolisp | ok | 2 | 86 KB | 42 |
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
- **tcc** ✅ (rescued) — musl `--config-musl` dies in `libtcc1/bcheck.o`
  (`incompatible redefinition of wchar_t`); builds cleanly on **debian/glibc**.
  Also: clone from the `github.com/TinyCC/tinycc` mirror (`repo.or.cz` timed out
  from the builder), and `make install` so `tcc -run` finds its own headers +
  `libtcc1.a`. 418 KB.
- **femtolisp** ✅ (rescued) — `llt` headers need glibc `__gnu_linux__` *and*
  `__x86_64__`, so it builds on **debian under amd64 emulation** (recipe `arch`
  file = `amd64`). Also build the `release` target (default also runs the test
  suite, which exits 127 here). 203 KB. A native arm64/musl port would need
  header patches.
- **cproc** ❌ (deferred) — builds cproc + QBE, but `qbe` rejects IR keyword
  `extern` that the cproc frontend emits → cproc/qbe version skew. Need matching
  pinned commits. (Also found: the `8l/qbe` mirror has a `$define` typo on its
  aarch64 Makefile branch; `michaelforney/qbe` fixes that but the skew remains.)

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

#### Batch 4 — mined from `data/shortlist.tsv` (29 green total)
First batch sourced from the **list-mining pipeline** rather than memory.
- ✅ **partcl** (zserge micro-Tcl, single file, built-in stdin REPL), **ubasic**
  (Adam Dunkels tiny BASIC — library-only, so we add `recipes/ubasic/main.c` to
  run a `.bas` file), **ape** (single-file amalgamation; CLI via `examples/`),
  **brainfuck** (fabianishere, cmake; run a committed `hello*.bf`), **yoctolisp**
  (builtin is `print`, not `display`), **lci** (LOLCODE; needs
  `readline-dev`+`ncurses-dev`), **mac** (bytecode VM demo; runs a hardcoded 5+6).
- All tiny: most binaries 73–86 KB; lci is 1.6 MB (readline/ncurses).
- ❌ **atto** (Rust) — pinned `nix` crate (via rustyline) won't compile on
  alpine/musl with the current toolchain. Needs dep/toolchain pinning.
- Skipped this round (noted for later): **c4 / write-a-C-interpreter** store
  pointers in `int` (assume ILP32 — segfault on any 64-bit target, arch-independent);
  **wac** hardcodes `-m32` *and* needs Binaryen for a `.wasm`; **gforth** from git
  needs an existing gforth to bootstrap (use a release tarball); **uxn** moved off
  GitHub (now `git.sr.ht/~rabbits/uxn`); **streem** is an experimental prototype.
