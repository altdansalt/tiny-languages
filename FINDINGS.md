# Findings

Running log of build/test outcomes. Machine-readable results live in `results/*.json`;
`scripts/report.py` regenerates the summary table below.

## Summary

<!-- REPORT:BEGIN -->
| name | outcome | build (s) | binary | smoke |
|------|---------|-----------|--------|-------|
| chibi-scheme | ok | 16 | 234 KB | ok-chibi |
| cproc | fail | 4 | — |  |
| femtolisp | fail | 2 | — |  |
| janet | ok | 29 | 2.2 MB | ok janet |
| lua | ok | 61 | — | ok Lua 5.5 |
| tcc | fail | 15 | — |  |
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
