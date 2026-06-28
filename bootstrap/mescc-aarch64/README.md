# mescc-aarch64 — a new aarch64 backend for GNU Mes's MesCC

**Status: Milestone 1 reached ✅** — a brand-new `aarch64` code-generator backend
for GNU Mes's MesCC compiler that **compiles `int main(){return 42;}` to a native
aarch64 ELF and runs it (exit 42)**, entirely on this arm64 host. This is the piece
that has been missing from the bootstrappable ecosystem: it's the first step of a
path past M2-Planet to a *real* C compiler **natively on aarch64** (see PATHS.md #8 /
BOOTSTRAP.md "the gap").

## Why this matters

The native-arm64 bootstrap stalls at M2-Planet (a C-*subset* compiler) because the
canonical next rung — GNU Mes → MesCC → tcc → gcc — **has no aarch64 port**: MesCC's
code generators target only armv4 / riscv64 / x86_64. That's *the* reason
`bootstrap/mes` only runs under x86-64 emulation. This probe attacks that gap
directly by writing the absent backend.

## What it took (and why aarch64 was the tractable case)

A MesCC backend is two Scheme files — `info.scm` (registers, type sizes, the
instruction table) and `as.scm` (~100 functions, each emitting M1 assembler macros
for one IR op) — plus the arch wiring in `mescc.scm`, an ELF template, and a crt.

The decisive enabler: **M2libc already ships a complete, tested aarch64 instruction
vocabulary** (`aarch64_defs.M1`: `PUSH_X0`, `SET_BP_FROM_SP`, `SUB_SP_SP_X16`,
`LOAD_W0_AHEAD`, `RETURN`, `SYSCALL`, …) shaped exactly like MesCC's stack-machine
model — because M2-Planet's codegen is the same shape. So no new instruction
*encodings* had to be invented; the backend *composes existing macros*. The link
reuses the proven stage0/M2libc aarch64 toolchain (M1 + hex2) and a Mes-style ELF
header (riscv64's, with `e_machine` patched to AArch64 `0xB7`).

## Files (the overlay)

| file | what it is |
|------|-----------|
| `overlay/info.scm` | `(mescc aarch64 info)` — registers `x0,x1,x13–x15`, C type sizes, instruction table |
| `overlay/as.scm`   | `(mescc aarch64 as)` — the code generator (Milestone-1 subset; emits M2libc macros) |
| `overlay/patch.sed`| 3-line patch wiring `aarch64` into `mescc.scm` (arch dispatch, `__aarch64__`, module) |
| `overlay/crt1.M1`  | aarch64 `_start`: `INIT_SP`, call `:main`, `exit(x0)` |
| `Dockerfile`       | clones mes + mescc-tools + M2libc(+nyacc), installs the overlay, compiles & runs |

## The emitted code (proof the generator is real)

For `int main(){return 42;}` the new backend produces:

```
:main
    PUSH_LR / PUSH_BP / SET_BP_FROM_SP                 ; prologue
    LOAD_W16_AHEAD / SKIP_32_DATA / %8360 / SUB_SP_SP_X16   ; reserve locals
    LOAD_W0_AHEAD  / SKIP_32_DATA / %42                ; return value 42 -> x0
    SET_SP_FROM_BP / POP_BP / POP_LR / RETURN          ; epilogue
```

→ assembled by M1, linked to a 940-byte aarch64 ELF, runs, exits **42**.

(One real bug found and fixed along the way: M2libc's macros use **x18** as the
stack pointer, so `_start` must run `INIT_SP` (`mov x18, sp`) before the first
`PUSH`, or it faults.)

## What remains (honest scope — this is Milestone 1, not done)

This proves the backend *works*; it is **not** a self-hosting MesCC yet. To get from
here to "seed ⇒ tcc ⇒ gcc, natively on aarch64" still needs:

1. **The rest of `as.scm`** — the ~100 IR ops (arithmetic, comparisons→bool, loads/
   stores in byte/half/word, calls with args, shifts, globals, locals beyond the
   trivial). Many compose existing M2libc macros; the gaps (register-parameterized
   moves/ALU across `x0,x1,x13–x15`) need a handful of new macros — aarch64's regular
   `Rd[4:0]/Rn[9:5]/Rm[20:16]` fields make these straightforward to encode.
2. **A real crt + Mes libc** for aarch64 (argc/argv/envp, syscalls) rather than the
   minimal `_start` here.
3. **Bring-up by fixpoint**: compile progressively larger programs, then MesCC's own
   tcc target, until the new backend can build tinycc.

Each step is mechanical translation against the riscv64 backend as a template, with
M2libc as the encoding reference. The hard "is it even possible?" question is now
answered: **yes** — demonstrably, with a running binary.
