# mescc-aarch64 — a new aarch64 backend for GNU Mes's MesCC

**Status: a working C subset, incl. real I/O ✅** — a brand-new `aarch64`
code-generator backend for GNU Mes's MesCC compiler that **compiles a substantial
C subset to native aarch64 and runs it**, entirely on this arm64 host. The capstone:
it builds a `hello.c` that prints to stdout via a real `write(2)` syscall —

```
$ ./hello.elf
hello, aarch64! (compiled by a brand-new MesCC backend)
```

— proving the backend produces genuinely useful programs, not just exit codes.
This is the piece that has been missing from the bootstrappable ecosystem: the path
past M2-Planet to a *real* C compiler **natively on aarch64** (PATHS.md #8 /
BOOTSTRAP.md "the gap").

The backend now compiles: integer arithmetic with precedence, all of C's
comparisons and `if`/`while`/`for`/`do`/`switch` control flow, functions with
arguments and recursion, pointers and arrays, local and global variables, `char`,
bitwise and shift operators, signed/unsigned division and modulo, the logical and
compound-assignment operators, `++`/`--`, string literals, and basic structs — each
verified end-to-end (compiled → linked → run → result asserted) in
`overlay/run-tests.sh`.

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
- **Milestone 3** ✅ — **functions, arguments, and recursion**: multi-argument
  calls (`add3(10,20,12)`→42), and real recursion — `fact(5)`→120 and
  `fib(10)`→55. Adds the stack-based calling convention (`r->arg` pushes each
  argument, `call-label`/`call-r` call via `BLR` then pop the args), parameter
  access at positive BP offsets (negative MesCC offsets → `ADD` not `SUB`), and
  `swap-r-stack`/`swap-r1-stack` for reordering operands spilled across a call.
- **Milestone 5** ✅ — **division, modulo, and the rest of C's everyday surface**:
  `84/2`→42, `85%43`→42 (modulo via `SDIV`+`MSUB`), `for` loops, logical `!`/`&&`/
  `||`, compound assignment (`x+=2`), post-increment (`x++`, read-modify-write via
  `r-long-mem-add`), `switch`/`case` (`r-cmp-value`), `do/while`, and string
  literals (`s="*"; s[0]`→42). Adds signed/unsigned divide and remainder, 32→64
  zero-extension (`UXTW`), logical-negate, compare-with-immediate, and in-place
  memory increment.
- **Milestone 4** ✅ — **pointers, memory, globals, bitwise, and shifts**:
  pointer deref/assign (`*p=42`), local arrays (`a[0]+a[1]`), global scalars and
  arrays (`int g; gs[1]=42`), char globals, bitwise `& | ^`, and shifts `<< >>`.
  Adds the bitwise/shift ALU ops, width-aware loads/stores (`DEREF`/`STR` in
  byte/half/word/dword, with zero/sign extension via `UXTB/SXTB/UXTH/SXTH`),
  address-of-local (`local-ptr->r`), and label-addressed global storage. The last
  required emitting label references as MesCC's structured `(#:address ,label)`
  token (rendered by `M1.scm` via `global->string`/`function->string`) rather than
  a hand-built `&name`, so every label kind — strings, `<global>`/`<function>`
  records, nested address forms — resolves correctly.

**Two latent M2libc bugs found en route** (both in macros M2-Planet itself never
emits, so never exercised before — `extra.M1` defines corrected versions and the
backend routes around them; worth reporting upstream):
1. `ADD_X0_X16_X0` is mis-encoded as `add x0, x0, x0, lsl #8` (`0020008b`); the
   correct `add x0, x16, x0` is `0002008b` (`ADD_X0_X16_X0_OK`).
2. `ADD_SP_X16_SP` is mis-encoded as `add x18, x8, x18` (Rn=x8, not x16). Since x8
   is 0, post-call argument cleanup popped nothing — silently corrupting any value
   spilled across a call (`n*fact(n-1)` returned `(n-1)!`). Corrected to
   `add x18, x18, x16` = `5202108b` (`ADD_SP_SP_X16_OK`).

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
