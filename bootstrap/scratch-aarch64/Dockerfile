# Smallest possible base: FROM scratch (0-byte base image).
# Answer to "what's the smallest arm64 image for bootstrapping?": none at all.
# A 526-byte static seed + the kernel is enough — no shell, no libc, no /dev,
# no coreutils. We use exec-form RUN (which needs no /bin/sh) to drive the static
# seed; kaem builds its own coreutils, M1, hex2 and M2-Planet from there.
#
# Stage A (debian) only CLONES the sources and writes a test program; the actual
# bootstrap + compile + run all happen in the scratch stage.
FROM debian:bookworm-slim AS fetch
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 --recursive https://github.com/oriansj/stage0-posix /s0
RUN printf 'int main() { return 0; }\n' > /return.c

FROM scratch
COPY --from=fetch /s0 /s0
COPY --from=fetch /return.c /return.c
WORKDIR /s0
# 1) bootstrap the toolchain from the 526-byte seed (exec form, no shell)
RUN ["/s0/bootstrap-seeds/POSIX/AArch64/kaem-optional-seed", "/s0/AArch64/mescc-tools-seed-kaem.kaem"]
RUN ["/s0/AArch64/artifact/kaem-0", "/s0/AArch64/mescc-tools-mini-kaem.kaem"]
RUN ["/s0/AArch64/bin/kaem", "--verbose", "--strict", "--file", "/s0/AArch64/kaem.run"]
# 2) the seed-built compiler compiles a C program ...
RUN ["/s0/AArch64/bin/M2-Planet", "--architecture", "aarch64", "-f", "/return.c", "-o", "/return.M1"]
RUN ["/s0/AArch64/bin/M1", "-f", "/s0/M2libc/aarch64/aarch64_defs.M1", "-f", "/s0/M2libc/aarch64/libc-core.M1", "-f", "/return.M1", "--little-endian", "--architecture", "aarch64", "-o", "/return.hex2"]
RUN ["/s0/AArch64/bin/hex2", "-f", "/s0/M2libc/aarch64/ELF-aarch64.hex2", "-f", "/return.hex2", "--little-endian", "--architecture", "aarch64", "--base-address", "0x00400000", "-o", "/prog"]
# 3) ... and the compiled program RUNS in the empty image (exit 0 => build passes)
RUN ["/prog"]
CMD ["/s0/AArch64/bin/M2-Planet", "--version"]
