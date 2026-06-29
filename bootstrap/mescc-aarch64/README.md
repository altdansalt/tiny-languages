# mescc-aarch64 — a new aarch64 backend for GNU Mes's MesCC

**Status: Milestone 2 reached ✅** — a brand-new `aarch64` code-generator backend
for GNU Mes's MesCC compiler that **compiles real integer arithmetic to native
aarch64 and runs it**, entirely on this arm64 host. This is the piece that has been
missing from the bootstrappable ecosystem: the path past M2-Planet to a *real* C
compiler **natively on aarch64** (see PATHS.md #8 / BOOTSTRAP.md "the gap").

- **Milestone 1** ✅ — `int main(){return 42;}` → a running native aarch64 ELF.
- **Milestone 2a** ✅ — a battery of arithmetic programs, each compiled, linked,
  run, and its exit code asserted (`overlay/run-tests.sh`):
  `2+3*4`→14 (precedence), `(10-4)*2`→12, `1+2+3+4+5`→15 (chained adds + immediate
  folding), `100-58`→42 (subtraction), `2*3*7`→42 (chained multiply). Exercises
  operator precedence, register spilling to the x18 stack, and constant folding.
- **Milestone 2b** ✅ — **comparisons, conditional branches, and loops**:
  `while(i<10){i=i+1;}`→10, `if(i<3){...}` (both taken and not), and two real
  multi-local algorithms — sum `1..5`→15 and `5!`→120. Adds signed comparisons
  (`<`,`<=`,`>`,`>=`,`==`,`!=`) via `SUBS`+`CSET`, conditional branches via
  `SUBS`+`B.cond` over an absolute `BR`, 32→64 sign-extension via `SXTW`, and a
  rewrite of local-variable addressing to use the **x13 scratch** so a live operand
  in x0/x1 survives while the other is loaded (the bug that made `s=s+i`→`2i`).

**Bug found in M2libc en route:** its `ADD_X0_X16_X0` macro is mis-encoded as
`add x0, x0, x0, lsl #8` (`0020008b`) — a latent bug, since M2-Planet only ever
accumulates into x1 and so never emits the x0 form. `extra.M1` defines the correct
`ADD_X0_X16_X0_OK` (`0002008b`) and the backend routes around it. (Worth reporting
upstream.)

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
| `overlay/info.scm`     | `(mescc aarch64 info)` — 2-register model (`x0,x1`), C type sizes, instruction table |
| `overlay/as.scm`       | `(mescc aarch64 as)` — the code generator: prologue/epilogue, immediates, stack spills, integer arithmetic, register moves |
| `overlay/extra.M1`     | a few hand-encoded aarch64 macros M2libc lacks (`SET_X0_FROM_X1`) or mis-encodes (`ADD_X0_X16_X0_OK`) |
| `overlay/patch.sed`    | 3-line patch wiring `aarch64` into `mescc.scm` (arch dispatch, `__aarch64__`, module) |
| `overlay/crt1.M1`      | aarch64 `_start`: `INIT_SP`, call `:main`, `exit(x0)` |
| `overlay/run-tests.sh` | the smoke battery — compiles/links/runs each test program, asserts its exit code |
| `Dockerfile`           | clones mes + mescc-tools + M2libc(+nyacc), installs the overlay, runs the battery |

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
