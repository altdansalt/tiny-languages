# Bootstrapping paths — proposal and exploration

`BOOTSTRAP.md` maps the dependency stack and records the bootstrap *edges* already
verified here. This file does the next thing the project asked for: **propose
multiple distinct bootstrapping paths, judge each for feasibility on this host,
then explore the viable ones** with new container probes.

"Path" here means: a *route to a self-hosting/trusted compiler or whole system*,
starting from the smallest root of trust the route allows. They are deliberately
*different families* — reduced-binary seeds, self-hosting languages, whole-system
emulators, sector-sized seeds — because each teaches a different lesson about where
trust bottoms out.

## Host constraints that decide feasibility

Every verdict below follows from three verified facts about this machine:

1. **Host is arm64 (Apple silicon).** Native aarch64 containers run at full speed.
2. **Rosetta runs x86-64, but not 32-bit x86.** `--arch amd64` works; a `gcc -m32`
   binary builds but won't `exec` (verified). No 32-bit ARM either.
3. **`qemu-system-*` runs *inside* a container** (apt-installable). That's full-system
   emulation, independent of Rosetta — so 16-bit/x86 boot code *can* be booted, and
   non-host ISAs (Knight, Oberon RISC) *can* be emulated, as a smoke test.

So the feasibility ladder is: **native-arm64** (best) → **amd64-via-Rosetta** (slower,
x86-64 only) → **qemu-full-system-in-container** (any ISA, slowest) → **impossible
here** (needs 32-bit native, or a binary-only seed we won't trust).

## The paths, ranked by value × feasibility-on-this-host

| # | Path | Family | Reaches | Root of trust | Host feasibility | Status |
|---|------|--------|---------|---------------|------------------|--------|
| 1 | **stage0-posix → M2-Planet** | reduced-binary seed | C-subset compiler | 526-byte seed | native-arm64 | ✅ verified |
| 2 | **OCaml `make bootstrap`** | self-hosting language | full OCaml compiler reproduces its own bytecode seed | ~2 MB shipped bytecode `boot/` + a C compiler | native-arm64 | 🔨 exploring |
| 3 | **Minimal aarch64 Linux kernel** | whole-system / Tier 0 | a bootable `Image`, booted to a console | from-source kernel + GCC | native-arm64 (+ qemu boot) | 🔨 exploring |
| 4 | **tcc self-host + tcc→lua** | self-hosting C compiler | tcc reproduces itself; builds a language | a seed C compiler | native-arm64 | ✅ verified |
| 5 | **cproc+QBE self-host** | self-hosting C compiler | clean C11→SSA→native compiler reproduces itself | a seed C compiler | native-arm64 | 🔨 exploring |
| 6 | **SectorFORTH under qemu** | sector-sized seed | interactive Forth from a 512-byte boot sector | 512-byte hand-written x86 asm | qemu-i386-in-container | 🔨 exploring |
| 7 | **GCC from source (self-contained)** | the heavyweight compiler | GCC 14.2 with gmp/mpfr/mpc/binutils *also* from source | a seed C compiler | native-arm64 | ◑ partial (apt prereqs) |
| 8 | **M2-Planet → GNU Mes → tcc** | reduced-binary seed (cont.) | a *real* C compiler from the seed chain | the seed chain | amd64-via-Rosetta only | ◑ mes builds; chain unstitched |
| 9 | **Project Oberon (RISC emulator)** | whole self-hosting system | Wirth's compiler+OS, self-recompiling | ~3 KB C emulator + disk image | qemu-less (native C emu) but needs GUI/headless | ○ proposed |
| 10 | **SectorLISP under qemu** | sector-sized seed | a LISP REPL from a 512-byte boot sector | 512-byte hand-written x86 asm | qemu-i386-in-container | ○ proposed |
| 11 | **Go / Rust / GHC / FPC self-host** | self-hosting language | their modern compilers | a *prior binary* of themselves | native-arm64 but **needs a binary seed** | ✗ rejected (see below) |
| 12 | **live-bootstrap seed⇒GCC (one run)** | reduced-binary seed (full) | full GCC from a hex0 seed, unbroken | a 32-bit x86 hex0 seed | **impossible here** (32-bit x86) | ✗ needs an x86-64/VM host |

### Why some paths are rejected or deferred

- **#11 self-hosting languages that need their own prior binary** (Go, GHC, Free
  Pascal, Chez, and Rust-without-mrustc). These *self-host* but do not *bootstrap
  from something smaller* — you need a trusted binary of the same compiler to start.
  Go's old C-based Go1.4 seed is effectively retired (modern Go bootstraps Go1.4→
  1.17→…→latest from a *Go* binary or `gccgo`); GHC only builds with GHC; FPC only
  with FPC. Interesting as *self-host* demos, but they don't lower the root of trust,
  which is the point of this exercise. **Rust via mrustc** is the exception that
  *does* lower trust (C++ → rustc), but it's a 6–12 h build — deferred, not rejected.
- **#12 live-bootstrap** is the canonical "hex0 ⇒ GCC in one unbroken run", but it is
  x86/i386-only and its seed is 32-bit x86 — which this host cannot exec (constraint
  2). It belongs on a native x86-64 Linux box / VM. Documented in BOOTSTRAP.md.
- **#8 Mes chain** is the native-feeling continuation of #1, but GNU Mes has **no
  aarch64 backend** (MesCC targets armv4/riscv64/x86-64), so past M2-Planet it only
  proceeds under x86-64 emulation. The `bootstrap/mes` probe builds Mes on amd64;
  stitching M2-Planet→Mes→tcc into one run is future work.

## What "exploring" produces

The 🔨 paths become new probes under `bootstrap/`, each with a smoke test, run by
`scripts/build.sh <name>` and recorded in `results/`. Diversity is intentional —
three different *kinds* of root of trust, all runnable on this host:

- **#2 OCaml** — a real, widely-used compiler that **reproduces its own seed**
  (`make world` then `make bootstrap` rebuilds the shipped `boot/` bytecode with the
  freshly built compiler). The cleanest "self-hosting language" demonstration that is
  also native aarch64.
- **#3 kernel** — the one Tier-0 artifact, and the one thing the tiny compilers
  *can't* build: a from-source aarch64 `Image`, then **booted under
  qemu-system-aarch64** with a BusyBox initramfs to a real `/ # ` console.
- **#5 cproc+QBE** — the cleanest small "real" C compiler (C11 front end → SSA → a
  portable backend), shown **reproducing itself** natively.
- **#6 SectorFORTH** — the smallest, most visceral root of trust: a **512-byte**
  hand-written boot sector that is a working Forth, **booted under qemu** and driven
  to evaluate an expression. Demonstrates the qemu-in-container capability too.

Results land in `results/`; this table's Status column tracks each one.
