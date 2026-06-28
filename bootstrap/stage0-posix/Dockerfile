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
# the root of trust: how few bytes we had to trust to get here
RUN printf 'BINSIZE %s hex0-seed\n' \
    "$(stat -c %s bootstrap-seeds/POSIX/AArch64/hex0-seed)"
CMD ["sh", "-c", "AArch64/bin/M2-Planet --version 2>&1 | head -1 || echo 'M2-Planet bootstrapped from a 526-byte seed'"]
