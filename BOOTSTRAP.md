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

## Open frontiers (closing the bottom of the stack)

The repo proves the *upper* layers; the genuinely hard, interesting part is the
floor. Concrete next probes, each a candidate recipe/experiment:

1. **Build musl from source** in a container (it builds with just a C compiler) —
   turns Tier 3 from "consumed" into "verified".
2. **Build GCC from source** (and/or a cross-binutils) — the heavyweight seed.
3. **The real seed chain** — wire up the existing "bootstrap the world" projects as
   verified recipes:
   - **stage0** (`oriansj/stage0`) — hex0 → hex1 → … a few hundred bytes of seed.
   - **M2-Planet** + **mescc / GNU Mes** — a minimal C compiler reachable from the
     stage0 seed; Mes can build a tinycc that can build GCC.
   - **live-bootstrap** (`fosslinux/live-bootstrap`) — the full documented path from
     a ~357-byte seed to a working GCC/userland. This is the canonical map for the
     exact thing this section is about.
4. **Build a Linux kernel** in-container with the host GCC (Tier 0→userland),
   then probe how minimal a config + toolchain it tolerates.
5. **tcc self-host + tccboot** — verify tcc compiling tcc, and (stretch) tcc
   building a small kernel, to measure how far the *tiny* compilers reach down.

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
