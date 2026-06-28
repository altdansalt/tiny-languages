# Bootstrapping the world

Goal: chart a path from bare metal up — kernel, a C compiler, a libc, the
languages most software is written in, then the long tail of tiny languages —
using the verified builds in this repo as evidence for *what depends on what*.

The single most useful fact this repo establishes: **28 of the 30 verified
languages need nothing but a C toolchain + a libc + a build tool (make/cmake) to
build.** Only two need another *language* to pre-exist (goawk → Go, mruby → Ruby).
Everything bottoms out at **C**. So the bootstrap problem reduces to: get a C
compiler + libc + binutils + a kernel, and (almost) the whole catalog follows.

## The bootstrap stack (tiers)

```
Tier 0  Hardware + Linux kernel
Tier 1  Assembler + linker            binutils (as, ld)        ← cproc literally lists this
Tier 2  A C compiler                  gcc (seed) │ tcc │ cproc+qbe
Tier 3  A C library                   musl (alpine) │ glibc (debian)
Tier 4  Build drivers                 make → cmake, bison/flex, autotools/m4
Tier 5  Languages written in C/C++    ← 27 of the 30 here (see table)
Tier 6  Languages needing a host lang  mruby ⇐ Ruby,  goawk ⇐ Go,  atto ⇐ Rust
        …and each host language is itself C-rooted (CPython, Ruby, the Go/Rust
        bootstrap chains all terminate at a C compiler).
```

Tiers 1–4 are the "seed platform". This repo currently *consumes* tiers 1–3 from
Alpine/Debian rather than building them from source — see **Open frontiers** below
for closing that gap.

## The C-bootstrappable core

Buildable with only `{C compiler, libc, make/cmake}` — no other language runtime.
The very tiniest seeds are **pure C with zero extra libraries**, compiled with a
bare `cc` (no make even): `fe`, `picol`, `partcl`, `ubasic` — single translation
units, 73–86 KB. These are the things you can stand up first on a fresh C compiler.

Two tiny **C compilers** are themselves in the set, which is the interesting part
for self-hosting:
- **tcc** — Tiny C Compiler. Compiles C directly to machine code in one pass, can
  recompile itself, and historically booted Linux 2.4 (`tccboot`). A plausible
  *second-stage* C compiler once a seed compiler exists.
- **cproc + QBE** — a C11 front end (cproc) emitting SSA IR to a small portable
  backend (QBE) that targets x86-64 / arm64 / riscv64, then `as`+`ld`. The cleanest
  small "real" compiler architecture here; QBE is reusable as a backend for *new*
  languages too.

## Bootstrap chains (where C isn't enough on its own)

| language | needs first | …which needs | terminates at |
|----------|-------------|--------------|---------------|
| mruby | Ruby + rake | CRuby (written in C) | **C** |
| goawk | Go toolchain | Go (self-hosting; earlier Go was bootstrapped via C, now via prior Go / `gccgo`) | **C** (gccgo) or a prior Go |
| atto (deferred) | Rust/cargo | rustc (self-hosting; bootstrap chain via OCaml→Rust, mrustc in C++) | **C/C++** (mrustc) |

The lesson: every chain dead-ends at a C (or C++) compiler. A from-scratch system
needs *one* trusted C compiler; the rest is layering.

Note also a few **build-time helpers** that are tools, not host languages:
`bison`/`flex` (onetrueawk, parser generators — themselves C), `python3` used only
as a build *script* runner (micropython, berry — not needed at runtime), and `m4`
(which we also build as a language in its own right — it's part of autotools).

## Roads to "the languages most software uses"

| language family | tiny C-rooted route in this repo | full route |
|-----------------|----------------------------------|-----------|
| C / C++ | tcc, cproc+qbe | gcc / clang (needed for the kernel) |
| Lua | **lua** (362 KB) | same; Lua is already tiny |
| JavaScript | **quickjs-ng** | V8/SpiderMonkey (huge) |
| Python | **micropython** (258 KB) | CPython (C) |
| Ruby | **mruby** (needs Ruby to build) | CRuby (C) |
| Scheme/Lisp | chibi-scheme, femtolisp, fe, yoctolisp | — |
| Forth | pforth (self-hosting from C) | gforth |

Every cell is reachable from a C compiler. The one thing the *tiny* compilers here
**cannot** do is build a modern **Linux kernel** — that needs GCC (or Clang) plus
specific extensions; tcc/cproc are not drop-in replacements. So "build a kernel"
keeps GCC on the critical path even though everything else can shed it.

## Runtime footprint — what they actually link

Captured with `ldd` inside each built image (`scripts/runtime_deps.sh` →
`data/runtime_libs.tsv`). This is the *use*-time counterpart to the build table:

- **22 of 30 link nothing but the C library** (musl `libc` + its loader; musl folds
  `libm` into `libc`). That is the strongest possible "tiny / bare-Pi / sandbox"
  signal — drop the binary next to a libc and it runs.
- **goawk** is **fully static** (Go links everything in) — zero shared-lib deps at all.
- Heavier linkers, and why:
  - **lci** → `libreadline` + `libncursesw` (interactive REPL).
  - **squirrel** → `libstdc++` + `libgcc_s` (it's C++), plus its own
    `libsquirrel`/`libsqstdlib`.
  - **chibi-scheme** → its own `libchibi-scheme.so` (installed shared runtime).
  - **tcc**, **femtolisp** → glibc (`libc.so.6`, `libm.so.6`) because they're the
    two builds on a Debian base; on glibc `libm` is a separate object.

Takeaway for bootstrapping: the runtime requirement for most of the catalog is
*just a C library*. Pick musl and almost the whole set is a single static-ish
dependency away from running anywhere.

## Verified bootstrap edges (`bootstrap/`)

Demonstrated, not just argued — each is a container probe with a smoke test
(`scripts/build.sh <name>`, results in `results/`):

- **tcc-selfhost** ✅ — build tcc with gcc (stage 1), then rebuild tcc *using the
  stage-1 tcc* (`./configure --cc=/tcc-stage1`), then show the stage-2 tcc (a tcc
  built by tcc) compiles and runs a program. The self-hosting edge: the compiler
  reproduces itself.
- **tcc-builds-lua** ✅ — use tcc (not gcc) as `CC` to compile Lua from source, and
  run it → `ok-tcc-built-lua Lua 5.5`. A concrete edge **tcc → lua**: once you have a
  tiny C compiler, you can build a tiny language with it (gcc only seeds the tcc).

Together these show the interesting middle of the bootstrap graph working with the
*tiny* compiler, not GCC: `gcc ⇒ tcc ⇒ {tcc, lua, …}`. Replacing the `gcc ⇒ tcc`
seed step with a from-scratch chain (stage0 → M2-Planet → mes → tcc) is the
remaining gap below.

- **musl-from-source** ✅ (Tier 3 — libc) — build musl 1.2.5 from the upstream
  release tarball, then use its `musl-gcc` wrapper to compile+run a binary against
  the from-source libc. Built on a glibc base on purpose: musl only emits its gcc
  wrapper on a non-musl host (the wrapper's job is to redirect a glibc gcc to musl).
  The from-source musl installs its loader to `/lib/ld-musl-aarch64.so.1`, which is
  what the test binary runs against. Turns Tier 3 from *consumed* to *verified*.
- **gcc-from-source** ✅ (Tier 2 — the C compiler) — GCC **14.2.0** built from the
  GNU release tarball, single-stage (`--disable-bootstrap`), C-only, no multilib;
  prerequisites (gmp/mpfr/mpc) from apt. The freshly built `gcc` compiles+runs a
  program. ~8 min, 7.7 MB driver. The heavyweight seed of the whole stack.
  (Needed a 24 GB *builder* — `cc1plus` on `gimple-match-*.o` OOMs at the 2 GB
  default; see DECISIONS.)
- **stage0-posix** ✅ (the floor — seed → C compiler) — the striking one. From a
  **526-byte** hand-auditable seed binary (`hex0-seed`) and **no host C compiler**
  (deps: just `bash` + coreutils + git), `kaem.aarch64` bootstraps the M1 assembler,
  hex2 linker, **M2-Planet** (a C-subset compiler), *and* a set of POSIX coreutils.
  We verify the bootstrapped binaries against the repo's committed reproducibility
  checksums (`aarch64.answers` → `M2-Planet: OK`) and run the result (`M2-Planet
  v1.13.1`). Native aarch64, no emulation. This is the bottom of the stack made
  concrete: **526 bytes of trust ⇒ a working C compiler.**

### The chain, end to end (all verified here)

```
526-byte seed ⇒ M2-Planet (C compiler)          [stage0-posix]
   … from a C compiler you can build …
   tcc            [bootstrap edge: gcc⇒tcc, and tcc⇒tcc self-host]
   gcc 14.2       [gcc-from-source]
   musl libc      [musl-from-source]
   … and from {C compiler + libc} the whole catalog …
   tcc ⇒ lua, and the other 29 languages   [recipes/]
```
The one gap left in a *pure* chain: stage0's M2-Planet is a C **subset** compiler;
reaching full GCC from it goes through GNU Mes → tcc → gcc (the live-bootstrap
path). Each *link* here is verified; stitching M2-Planet⇒mes⇒tcc⇒gcc into one
unbroken run is the remaining stretch.

## Open frontiers (closing the bottom of the stack)

The repo proves the *upper* layers; the genuinely hard, interesting part is the
floor. Concrete next probes, each a candidate recipe/experiment:

1. ~~**Build musl from source**~~ ✅ done (`bootstrap/musl-from-source`).
2. ~~**Build GCC from source**~~ ✅ done (`bootstrap/gcc-from-source`, C-only
   single-stage). Next: build its gmp/mpfr/mpc prerequisites + binutils from source
   too, to remove the apt-provided pieces.
3. ~~**The real seed chain**~~ ✅ started — `bootstrap/stage0-posix` bootstraps
   M2-Planet from a 526-byte seed. Remaining: continue the chain **M2-Planet → GNU
   Mes → tcc → gcc** as one run (the `live-bootstrap` path,
   `fosslinux/live-bootstrap`), so the from-526-bytes line reaches full GCC unbroken.
4. ~~**tcc self-host**~~ ✅ done (`bootstrap/tcc-selfhost`). Stretch: `tccboot`
   (tcc building a small Linux).
5. **Build a Linux kernel** in-container with the from-source GCC (Tier 0→userland),
   then probe how minimal a config + toolchain it tolerates. *(The one thing the
   tiny compilers can't do — keeps GCC on the critical path.)*

---

Provenance table (auto-generated by `scripts/provenance.py` from the recipes):

<!-- PROV:BEGIN -->
| language | impl | needs host lang | libc | build | extra libs |
|----------|------|-----------------|------|-------|------------|
| ape | C | — | musl | make | — |
| berry | C | — | musl | cmake | — |
| brainfuck | C | — | musl | cmake | — |
| chibi-scheme | C | — | musl | make | — |
| clox | C | — | musl | make | — |
| cproc | C | — | musl | configure | binutils |
| fe | C | — | musl | cc | — |
| femtolisp | C | — | glibc | make | — |
| gravity | C | — | musl | make | — |
| janet | C | — | musl | make | — |
| lci | C | — | musl | cmake | ncurses-dev, readline-dev |
| lua | C | — | musl | make | readline-dev |
| m4 | C | — | musl | configure+tarball | — |
| mac | C | — | musl | make | — |
| micropython | C | — | musl | make | libffi-dev, pkgconf |
| onetrueawk | C | — | musl | make | — |
| partcl | C | — | musl | cc | — |
| pforth | C | — | musl | cmake | — |
| picol | C | — | musl | cc | — |
| pocketlang | C | — | musl | make | — |
| quickjs-ng | C | — | musl | cmake | — |
| squirrel | C++ | — | musl | cmake | — |
| tcc | C | — | glibc | configure | — |
| ubasic | C | — | musl | cc | — |
| umka | C | — | musl | make | — |
| wasm3 | C | — | musl | cmake | — |
| wren | C | — | musl | make | — |
| yoctolisp | C | — | musl | make | — |
| goawk | Go | Go | musl | go | — |
| mruby | C | Ruby | musl | rake | — |
<!-- PROV:END -->
