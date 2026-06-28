# Bootstrap probe (the floor): stage0-posix — bootstrap a full C-compiler toolchain
# from a ~530-byte seed binary, with NO pre-existing C compiler.
#
# kaem.aarch64 runs: a tiny hex0/kaem seed builds mescc-tools (M1 assembler, hex2
# linker), which build M2-Planet (a C-subset compiler) and even a set of POSIX
# coreutils — all from source, seeded only by the hand-auditable seed binary.
# Note the deps: bash + coreutils + git. **No gcc/build-base.**
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates bash \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --recursive https://github.com/oriansj/stage0-posix .
# bootstrap from the seed (native aarch64; no emulation, no host C compiler)
RUN bash kaem.aarch64
# proof 1: the bootstrap produced a real C compiler (M2-Planet) as an ELF binary
RUN test -x AArch64/bin/M2-Planet && test -x AArch64/bin/M1 && test -x AArch64/bin/hex2 \
    && head -c4 AArch64/bin/M2-Planet | grep -qa 'ELF' \
    && echo "bootstrapped M2-Planet is an ELF executable"
# proof 2: reproducibility — the bootstrapped binaries match the committed sums
RUN sha256sum -c aarch64.answers | tee /smoke.out \
    && grep -q 'AArch64/bin/M2-Planet: OK' /smoke.out
# proof 3 (the unbroken chain): the SEED-BUILT compiler compiles a C program to a
# runnable ELF, using only seed-bootstrapped tools (M2-Planet -> M1 -> hex2).
# 526 bytes of trust  =>  C compiler  =>  a working compiled binary.
RUN printf 'int main() { return 42; }\n' > /return.c \
    && AArch64/bin/M2-Planet --architecture aarch64 -f /return.c -o /return.M1 \
    && AArch64/bin/M1 -f M2libc/aarch64/aarch64_defs.M1 -f M2libc/aarch64/libc-core.M1 \
        -f /return.M1 --little-endian --architecture aarch64 -o /return.hex2 \
    && AArch64/bin/hex2 -f M2libc/aarch64/ELF-aarch64.hex2 -f /return.hex2 \
        --little-endian --architecture aarch64 --base-address 0x00400000 -o /return.elf \
    && { /return.elf; [ $? -eq 42 ]; } \
    && echo "the seed-built compiler produced a working binary (returned 42)"
# the root of trust: how few bytes we had to trust to get here
RUN printf 'BINSIZE %s hex0-seed\n' \
    "$(stat -c %s bootstrap-seeds/POSIX/AArch64/hex0-seed)"
CMD ["sh", "-c", "AArch64/bin/M2-Planet --version 2>&1 | head -1 || echo 'M2-Planet bootstrapped from a 526-byte seed'"]
