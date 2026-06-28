# Bootstrap probe (Tier 2): build the GCC C compiler from source.
# Single-stage (--disable-bootstrap), C only, no multilib — the tractable
# "build a real C compiler from source" milestone. Prerequisites (gmp/mpfr/mpc)
# come from apt here; a fuller bootstrap would build those from source too.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates flex \
        libgmp-dev libmpfr-dev libmpc-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN wget -q https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz \
    && tar xf gcc-14.2.0.tar.xz
RUN mkdir build && cd build \
    && ../gcc-14.2.0/configure --prefix=/opt/gcc \
         --disable-bootstrap --disable-multilib \
         --enable-languages=c --disable-libsanitizer \
    && make -j4 \
    && make install
# NOTE: GCC's generated gimple-match-*.o / insn-*.o each need ~2-3 GB to compile;
# -j4 caps peak memory (8x would OOM-kill cc1plus even with 12 GB).
# proof: the freshly built GCC compiles and runs a program
RUN printf '#include <stdio.h>\nint main(){printf("ok-gcc\\n");return 0;}\n' > /h.c \
    && /opt/gcc/bin/gcc /h.c -o /h && /h | tee /smoke.out && grep -q '^ok-gcc' /smoke.out
RUN /opt/gcc/bin/gcc --version | head -1
RUN printf 'BINSIZE %s gcc\n' "$(stat -c %s /opt/gcc/bin/gcc)"
CMD ["/opt/gcc/bin/gcc", "--version"]
