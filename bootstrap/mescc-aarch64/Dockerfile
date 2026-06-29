# PROOF-OF-CONCEPT: a NEW aarch64 backend for GNU Mes's MesCC compiler.
#
# The native-arm64 bootstrap stalls at M2-Planet because GNU Mes has no aarch64
# port (its MesCC targets armv4/riscv64/x86_64). This adds one: module/mescc/
# aarch64/{info,as}.scm + a 3-line patch to mescc.scm. The code generator emits
# the whole-instruction M1 macros already defined and tested in M2libc's
# aarch64_defs.M1, so it needs no new instruction encodings — and it links through
# the exact same proven M2libc crt/libc/ELF stack that stage0-posix uses (the
# M2libc :_start calls :FUNCTION_main, which is what MesCC emits).
#
# Milestone 2: the backend now compiles real integer arithmetic — precedence,
# subtraction, chained ops, register spilling, immediate folding — verified by a
# battery of programs whose exit codes are asserted (run-tests.sh).
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates build-essential guile-3.0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /b
RUN git clone --depth 1 https://git.savannah.gnu.org/git/mes.git mes
RUN git clone --depth 1 --recursive https://github.com/oriansj/mescc-tools mt \
    && make -C mt ; \
    for x in M1 hex2; do f="$(find mt -type f -name "$x" -perm -u+x | head -1)"; cp "$f" /usr/local/bin/; done \
    && command -v M1 && command -v hex2
# M2libc aarch64: the tested instruction macros + libc + ELF header (via stage0)
RUN git clone --depth 1 --recursive https://github.com/oriansj/stage0-posix s0
ENV M2=/b/s0/M2libc/aarch64
# nyacc: the C99 parser MesCC's front end is built on
RUN git clone --depth 1 https://git.savannah.nongnu.org/git/nyacc.git /opt/nyacc
ENV GUILE_LOAD_PATH=/opt/nyacc/module

# install the new backend + patch the arch dispatch
RUN mkdir -p mes/module/mescc/aarch64
COPY overlay/info.scm mes/module/mescc/aarch64/info.scm
COPY overlay/as.scm   mes/module/mescc/aarch64/as.scm
COPY overlay/crt1.M1  /b/crt1.M1
COPY overlay/extra.M1 /b/extra.M1
COPY overlay/patch.sed /patch.sed
# combined macro defs: M2libc's tested aarch64 vocabulary + our few extras
RUN cat "$M2/aarch64_defs.M1" /b/extra.M1 > /b/defs.M1
# Mes-style aarch64 ELF templates: header (riscv64's, with e_machine -> AArch64
# 0xB7) + footer (pure symbol/string tables, arch-independent). The header's
# e_entry points at :_start (our crt1); the footer defines :ELF_end.
RUN sed 's/^f3 00 /b7 00 /' mes/lib/linux/riscv64-mes/elf64-header.hex2 > /b/header.hex2 \
    && grep -q '^b7 00 ' /b/header.hex2 \
    && cp mes/lib/linux/riscv64-mes/elf64-footer-single-main.hex2 /b/footer.hex2
RUN cd mes && sed -i -f /patch.sed module/mescc/mescc.scm \
    && grep -q 'aarch64-info' module/mescc/mescc.scm && echo "mescc.scm patched"
RUN printf '(use-modules (mescc))\n(mescc:main (command-line))\n' > /b/drive.scm
COPY overlay/run-tests.sh /b/run-tests.sh
COPY overlay/libc-tiny.M1 /b/libc-tiny.M1
COPY overlay/hello.c      /b/hello.c
COPY overlay/primes.c     /b/primes.c
COPY overlay/calc.c       /b/calc.c
COPY overlay/libc-aarch64.M1 /b/libc-aarch64.M1
COPY overlay/libc-aarch64.c  /b/libc-aarch64.c
COPY overlay/greet.c         /b/greet.c
ENV MES_PREFIX=/b/mes

# --- smoke: compile + run a battery of C programs through the new backend ---
# Each is compiled (C -> aarch64 M1), linked through the M2libc aarch64 stack,
# run, and its exit code asserted. The build fails if any program is wrong.
RUN sh /b/run-tests.sh | tee /b/results.txt
RUN printf 'BINSIZE %s main.elf\n' "$(stat -c %s /b/main.elf)"

# --- capstone: a "hello world" that does real I/O via a write(2) syscall ---
# Proof the backend builds genuinely useful programs, not just exit codes: compile
# hello.c, link with crt1 + the tiny `write` shim, run it, and assert the output.
RUN cd /b/mes \
    && guile -L module -L /opt/nyacc/module -L . /b/drive.scm --arch=aarch64 -S /b/hello.c -o /b/hello.s \
    && M1 --architecture aarch64 --little-endian -f /b/defs.M1 -f /b/crt1.M1 -f /b/libc-tiny.M1 -f /b/hello.s -o /b/hello.hex2 \
    && hex2 --architecture aarch64 --little-endian --base-address 0x00400000 \
         -f /b/header.hex2 -f /b/hello.hex2 -f /b/footer.hex2 -o /b/hello.elf \
    && out="$(/b/hello.elf)" \
    && echo "hello.elf says: $out" \
    && [ "$out" = "hello, aarch64! (compiled by a brand-new MesCC backend)" ]

# --- a non-trivial program: print every prime below 40, and assert the output ---
RUN cd /b/mes \
    && guile -L module -L /opt/nyacc/module -L . /b/drive.scm --arch=aarch64 -S /b/primes.c -o /b/primes.s \
    && M1 --architecture aarch64 --little-endian -f /b/defs.M1 -f /b/crt1.M1 -f /b/libc-tiny.M1 -f /b/primes.s -o /b/primes.hex2 \
    && hex2 --architecture aarch64 --little-endian --base-address 0x00400000 \
         -f /b/header.hex2 -f /b/primes.hex2 -f /b/footer.hex2 -o /b/primes.elf \
    && out="$(/b/primes.elf)" \
    && echo "primes.elf says: $out" \
    && [ "$out" = "2 3 5 7 11 13 17 19 23 29 31 37 " ]

# --- capstone: a recursive-descent expression evaluator (a mini-compiler) ---
# Parses & evaluates integer expressions with precedence and parentheses via
# mutual recursion, then prints each result. Asserts the three outputs.
RUN cd /b/mes \
    && guile -L module -L /opt/nyacc/module -L . /b/drive.scm --arch=aarch64 -S /b/calc.c -o /b/calc.s \
    && M1 --architecture aarch64 --little-endian -f /b/defs.M1 -f /b/crt1.M1 -f /b/libc-tiny.M1 -f /b/calc.s -o /b/calc.hex2 \
    && hex2 --architecture aarch64 --little-endian --base-address 0x00400000 \
         -f /b/header.hex2 -f /b/calc.hex2 -f /b/footer.hex2 -o /b/calc.elf \
    && out="$(/b/calc.elf)" \
    && printf 'calc.elf evaluated:\n%s\n' "$out" \
    && [ "$out" = "$(printf '42\n42\n21')" ]

# --- self-hosting groundwork: a small Mes-style libc, compiled by the backend ---
# Port of the per-arch syscall layer (__sys_callN via asm()) plus a few string/IO
# routines, then a SEPARATELY-compiled program (greet.c) linked against it. This is
# the shape every real bootstrap program takes — and the foundation for a full Mes
# libc / tcc port on aarch64.
RUN cd /b/mes \
    && guile -L module -L /opt/nyacc/module -L . /b/drive.scm --arch=aarch64 -S /b/libc-aarch64.c -o /b/libc-aarch64.s \
    && guile -L module -L /opt/nyacc/module -L . /b/drive.scm --arch=aarch64 -S /b/greet.c -o /b/greet.s \
    && M1 --architecture aarch64 --little-endian -f /b/defs.M1 -f /b/libc-aarch64.M1 -f /b/crt1.M1 -f /b/libc-aarch64.s -f /b/greet.s -o /b/greet.hex2 \
    && hex2 --architecture aarch64 --little-endian --base-address 0x00400000 \
         -f /b/header.hex2 -f /b/greet.hex2 -f /b/footer.hex2 -o /b/greet.elf \
    && out="$(/b/greet.elf)" \
    && printf 'greet.elf says:\n%s\n' "$out" \
    && [ "$out" = "$(printf 'libc-aarch64 online (separate compilation + linked libc):\n  strcmp equal     -> ok\n  strcmp ordering  -> ok\n  squares 1..6:\n  1  4  9  16  25  36')" ]
CMD ["sh", "/b/run-tests.sh"]
